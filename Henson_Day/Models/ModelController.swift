import Foundation
import SwiftData
import CoreLocation
import Combine

@MainActor
final class ModelController: ObservableObject {
    @Published private(set) var currentUser: PlayerEntity?
    @Published private(set) var pins: [PinEntity] = []
    @Published private(set) var leaderboardUsers: [PlayerEntity] = []
    @Published private(set) var isSeedLoading = true

    let modelContainer: ModelContainer
    private let context: ModelContext

    init() {
        let schema = Schema([
            PlayerEntity.self,
            PinEntity.self,
            BadgeEntity.self,
            CollectedItemEntity.self
        ])

        let config = ModelConfiguration("HensonDayOffline", schema: schema, isStoredInMemoryOnly: false)
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to initialize SwiftData container: \(error)")
        }

        context = ModelContext(modelContainer)

        Task {
            await loadAndSeedIfNeeded()
        }
    }

    func loadAndSeedIfNeeded() async {
        isSeedLoading = true

        do {
            let playerCount = try context.fetchCount(FetchDescriptor<PlayerEntity>())
            if playerCount == 0 {
                seedPlayers()
                seedPins()
                seedBadges()
                try context.save()
            }

            refreshPublishedData()
            isSeedLoading = false
        } catch {
            isSeedLoading = false
            print("SwiftData load/seed error: \(error)")
        }
    }

    func refreshPublishedData() {
        do {
            let players = try context.fetch(FetchDescriptor<PlayerEntity>())
            let pins = try context.fetch(FetchDescriptor<PinEntity>())

            self.currentUser = players.first(where: { $0.isLocalUser })
            self.pins = pins
            self.leaderboardUsers = players.sorted { $0.totalPoints > $1.totalPoints }
        } catch {
            print("SwiftData refresh error: \(error)")
        }
    }

    func captureCollectible(from pin: PinEntity, points: Int = 50) {
        guard let user = currentUser else { return }
        guard let collectibleName = pin.collectibleName else { return }

        do {
            let itemDescriptor = FetchDescriptor<CollectedItemEntity>(
                predicate: #Predicate { item in
                    item.collectibleName == collectibleName && item.player?.id == user.id
                }
            )
            let existing = try context.fetch(itemDescriptor)
            guard existing.isEmpty else { return }

            let collected = CollectedItemEntity(
                collectibleName: collectibleName,
                rarity: pin.collectibleRarity ?? "Common",
                foundAtTitle: pin.title,
                player: user
            )
            context.insert(collected)

            user.totalPoints += points
            user.collectedCount += 1

            try context.save()
            refreshPublishedData()
        } catch {
            print("Capture update error: \(error)")
        }
    }

    func collectionItemsForCurrentUser() -> [CollectedItemEntity] {
        guard let user = currentUser else { return [] }

        do {
            let descriptor = FetchDescriptor<CollectedItemEntity>(
                predicate: #Predicate { item in
                    item.player?.id == user.id
                },
                sortBy: [SortDescriptor(\CollectedItemEntity.foundAtDate, order: .reverse)]
            )
            return try context.fetch(descriptor)
        } catch {
            return []
        }
    }

    private func seedPlayers() {
        let seeded: [(String, String, AvatarType, Int, Bool)] = [
            ("You", "#D7263D", .turtle, 240, true),
            ("Avery", "#2D7FF9", .fox, 410, false),
            ("Jordan", "#5F6BFF", .panda, 360, false),
            ("Sam", "#0D9488", .owl, 335, false),
            ("Taylor", "#F59E0B", .rabbit, 290, false),
            ("Morgan", "#22C55E", .bear, 265, false),
            ("Riley", "#A855F7", .cat, 250, false),
            ("Casey", "#EC4899", .dragon, 230, false),
            ("Quinn", "#64748B", .eagle, 220, false),
            ("Parker", "#14B8A6", .otter, 205, false)
        ]

        seeded.forEach { row in
            let user = PlayerEntity(
                displayName: row.0,
                avatarColorHex: row.1,
                avatarType: row.2,
                totalPoints: row.3,
                collectedCount: row.4 ? 2 : Int.random(in: 0...4),
                isLocalUser: row.4
            )
            context.insert(user)
        }
    }

    private func seedPins() {
        let samplePins: [PinEntity] = [
            PinEntity(
                pinType: .event,
                title: "Stadium Spirit Rally",
                subtitle: "Day 1 • 5:00 PM – 7:00 PM • Maryland Stadium",
                latitude: 38.9903,
                longitude: -76.9457,
                pinDescription: "Show your Terp pride at the opening rally, featuring music and performances.",
                hasARCollectible: true,
                collectibleName: "Stadium Stomper",
                collectibleRarity: "Rare"
            ),
            PinEntity(
                pinType: .collectible,
                title: "McKeldin Time Capsule",
                subtitle: "Day 1 • Anytime • McKeldin Mall",
                latitude: 38.9857,
                longitude: -76.9456,
                pinDescription: "A hidden AR collectible near the center of the mall.",
                hasARCollectible: true,
                collectibleName: "Mall Muppet",
                collectibleRarity: "Common"
            ),
            PinEntity(
                pinType: .battle,
                title: "Terp Team Battle",
                subtitle: "Day 2 • 3:00 PM • Stamp Student Union",
                latitude: 38.9881,
                longitude: -76.9447,
                pinDescription: "Start a friendly AR faceoff and earn bonus points."
            ),
            PinEntity(
                pinType: .homebase,
                title: "Henson Homebase",
                subtitle: "Day 1–7 • 10:00 AM – 8:00 PM • Hornbake Plaza",
                latitude: 38.9889,
                longitude: -76.9418,
                pinDescription: "Check in to collect daily perks and hints."
            ),
            PinEntity(
                pinType: .concert,
                title: "Evening Concert",
                subtitle: "Day 3 • 7:30 PM • Chapel Field",
                latitude: 38.9878,
                longitude: -76.9392,
                pinDescription: "Live music and performances to close out the night."
            ),
            PinEntity(
                pinType: .site,
                title: "Idea Lab Showcase",
                subtitle: "Day 2 • 1:00 PM • Idea Factory",
                latitude: 38.9907,
                longitude: -76.9375,
                pinDescription: "Explore projects and mini demos built for Henson Day."
            )
        ]

        samplePins.forEach { context.insert($0) }
    }

    private func seedBadges() {
        let badges = [
            BadgeEntity(name: "Rally Starter", badgeDescription: "Attend your first event", iconName: "flag.fill"),
            BadgeEntity(name: "Collector", badgeDescription: "Collect 3 AR items", iconName: "cube.box.fill"),
            BadgeEntity(name: "Campus Explorer", badgeDescription: "Visit 5 unique pins", iconName: "map.fill")
        ]
        badges.forEach { context.insert($0) }
    }
}
