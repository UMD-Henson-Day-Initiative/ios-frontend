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
    @Published private(set) var startupErrorMessage: String?

    private(set) var modelContainer: ModelContainer?
    private var context: ModelContext?

    init() {
        initializeStore()
    }

    func retryInitialization() {
        initializeStore()
    }

    private func initializeStore() {
        isSeedLoading = true
        startupErrorMessage = nil
        currentUser = nil
        pins = []
        leaderboardUsers = []
        scheduleEvents = []
        collectibleCatalog = []

        let schema = Schema([
            PlayerEntity.self,
            PinEntity.self,
            BadgeEntity.self,
            CollectedItemEntity.self
        ])

        let config = ModelConfiguration("HensonDayOffline", schema: schema, isStoredInMemoryOnly: false)
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            modelContainer = container
            context = ModelContext(container)
        } catch {
            modelContainer = nil
            context = nil
            isSeedLoading = false
            startupErrorMessage = "Couldn't load offline data. Check device storage and try again."
            return
        }

        Task {
            await loadAndSeedIfNeeded()
        }
    }

    func loadAndSeedIfNeeded() async {
        guard let context else {
            isSeedLoading = false
            if startupErrorMessage == nil {
                startupErrorMessage = "Offline data is unavailable right now."
            }
            return
        }

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
            startupErrorMessage = "Couldn't prepare offline data. Please retry."
            print("SwiftData load/seed error: \(error)")
        }
    }

    func refreshPublishedData() {
        guard let context else {
            startupErrorMessage = "Offline data is unavailable right now."
            return
        }

        do {
            let players = try context.fetch(FetchDescriptor<PlayerEntity>())
            let pins = try context.fetch(FetchDescriptor<PinEntity>())

            self.currentUser = players.first(where: { $0.isLocalUser })
            self.pins = pins
            self.leaderboardUsers = players.sorted { $0.totalPoints > $1.totalPoints }
        } catch {
            startupErrorMessage = "Couldn't refresh local data."
            print("SwiftData refresh error: \(error)")
        }
    }

    func captureCollectible(from pin: PinEntity, points: Int = 50) {
        guard let collectibleName = pin.collectibleName else { return }
        captureCollectible(
            collectibleName: collectibleName,
            rarity: pin.collectibleRarity ?? "Common",
            foundAtTitle: pin.title,
            points: points
        )
    }

    func captureCollectible(collectibleName: String, rarity: String, foundAtTitle: String, points: Int) {
        guard let user = currentUser else { return }
        guard let context else {
            startupErrorMessage = "Offline data is unavailable right now."
            return
        }
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
                rarity: rarity,
                foundAtTitle: foundAtTitle,
                playerID: userID,
                player: user
            )
            context.insert(collected)

            user.totalPoints += points
            user.collectedCount += 1

            try context.save()
            refreshPublishedData()
        } catch {
            startupErrorMessage = "Couldn't save collectible progress."
            print("Capture update error: \(error)")
        }
    }

    func collectionItemsForCurrentUser() -> [CollectedItemEntity] {
        guard let user = currentUser else { return [] }
        guard let context else {
            startupErrorMessage = "Offline data is unavailable right now."
            return []
        }
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
            startupErrorMessage = "Couldn't load collected items."
            return []
        }
    }

    func hasCollectedCollectible(named collectibleName: String) -> Bool {
        guard let user = currentUser else { return false }
        guard let context else {
            startupErrorMessage = "Offline data is unavailable right now."
            return false
        }
        let userID = user.id

        do {
            let descriptor = FetchDescriptor<CollectedItemEntity>(
                predicate: #Predicate { item in
                    item.playerID == userID && item.collectibleName == collectibleName
                }
            )
            return try !context.fetch(descriptor).isEmpty
        } catch {
            startupErrorMessage = "Couldn't verify collectible progress."
            return false
        }
    }

    func updateCurrentUserAvatar(type: AvatarType, colorHex: String) {
        guard let user = currentUser else { return }
        guard let context else {
            startupErrorMessage = "Offline data is unavailable right now."
            return
        }
        user.avatarType = type
        user.avatarColorHex = colorHex

        do {
            try context.save()
            refreshPublishedData()
        } catch {
            startupErrorMessage = "Couldn't save avatar changes."
            print("Avatar update error: \(error)")
        }
    }

    func scheduleEventID(matchingPinTitle title: String) -> String? {
        let normalizedPinTitle = normalizeForMatching(title)

        if let exactMatch = scheduleEvents.first(where: {
            normalizeForMatching($0.title) == normalizedPinTitle
        }) {
            return exactMatch.id
        }

        if let containsMatch = scheduleEvents.first(where: {
            let candidate = normalizeForMatching($0.title)
            return candidate.contains(normalizedPinTitle) || normalizedPinTitle.contains(candidate)
        }) {
            return containsMatch.id
        }

        let pinTokens = Set(normalizedPinTitle.split(separator: " ").map(String.init))
        if pinTokens.isEmpty { return nil }

        let scored = scheduleEvents.compactMap { event -> (id: String, score: Int)? in
            let eventTokens = Set(normalizeForMatching(event.title).split(separator: " ").map(String.init))
            let overlap = pinTokens.intersection(eventTokens).count
            return overlap > 0 ? (event.id, overlap) : nil
        }
        .sorted { $0.score > $1.score }

        return scored.first?.id
    }

    private func normalizeForMatching(_ text: String) -> String {
        let lowered = text.lowercased()
        let cleaned = lowered.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : " "
        }
        return String(cleaned)
            .split(separator: " ")
            .joined(separator: " ")
    }

    private func seedPlayers() {
        guard let context else { return }
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
        guard let context else { return }
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
        guard let context else { return }
        let badges = [
            BadgeEntity(name: "Rally Starter", badgeDescription: "Attend your first event", iconName: "flag.fill"),
            BadgeEntity(name: "Collector", badgeDescription: "Collect 3 AR items", iconName: "cube.box.fill"),
            BadgeEntity(name: "Campus Explorer", badgeDescription: "Visit 5 unique pins", iconName: "map.fill")
        ]
        badges.forEach { context.insert($0) }
    }
}
