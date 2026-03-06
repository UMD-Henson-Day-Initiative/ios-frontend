import Foundation
import SwiftData
import CoreLocation
import Combine

@MainActor
final class ModelController: ObservableObject {
    @Published private(set) var currentUser: PlayerEntity?
    @Published private(set) var pins: [PinEntity] = []
    @Published private(set) var leaderboardUsers: [PlayerEntity] = []
    @Published private(set) var scheduleEvents: [DatabaseEvent] = []
    @Published private(set) var collectibleCatalog: [DatabaseCollectible] = []
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
            scheduleEvents = Database.events.sorted {
                ($0.dayNumber, $0.timeRange) < ($1.dayNumber, $1.timeRange)
            }
            collectibleCatalog = Database.collectibleCatalog
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
        let userID = user.id

        do {
            let itemDescriptor = FetchDescriptor<CollectedItemEntity>(
                predicate: #Predicate { item in
                    item.collectibleName == collectibleName && item.playerID == userID
                }
            )
            let existing = try context.fetch(itemDescriptor)
            guard existing.isEmpty else { return }

            let collected = CollectedItemEntity(
                collectibleName: collectibleName,
                rarity: pin.collectibleRarity ?? "Common",
                foundAtTitle: pin.title,
                playerID: userID,
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
        let userID = user.id

        do {
            let descriptor = FetchDescriptor<CollectedItemEntity>(
                predicate: #Predicate { item in
                    item.playerID == userID
                },
                sortBy: [SortDescriptor(\CollectedItemEntity.foundAtDate, order: .reverse)]
            )
            return try context.fetch(descriptor)
        } catch {
            return []
        }
    }

    private func seedPlayers() {
        Database.players.forEach { row in
            let user = PlayerEntity(
                displayName: row.displayName,
                avatarColorHex: row.avatarColorHex,
                avatarType: row.avatarType,
                totalPoints: row.totalPoints,
                collectedCount: row.collectedCount,
                isLocalUser: row.isLocalUser
            )
            context.insert(user)
        }
    }

    private func seedPins() {
        Database.pins.forEach { pin in
            context.insert(
                PinEntity(
                    pinType: pin.pinType,
                    title: pin.title,
                    subtitle: pin.subtitle,
                    latitude: pin.latitude,
                    longitude: pin.longitude,
                    pinDescription: pin.description,
                    hasARCollectible: pin.hasARCollectible,
                    collectibleName: pin.collectibleName,
                    collectibleRarity: pin.collectibleRarity
                )
            )
        }
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
