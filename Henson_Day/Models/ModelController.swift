import Foundation
import SwiftData
import CoreLocation
import Combine
import os
import SwiftUI

struct UserFacingErrorState: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
}

enum ScheduleEventStatus {
    case ended
    case active
    case upcoming
    case unavailable
    case featured
}

struct ScheduleEventPresentation: Identifiable {
    let event: DatabaseEvent
    let collectible: DatabaseCollectible?
    let availability: PinAvailabilityState
    let status: ScheduleEventStatus
    let isAdded: Bool

    var id: String { event.id }
}

struct ScheduleEventSection: Identifiable {
    let label: String
    let labelColor: Color
    let showsPulse: Bool
    let items: [ScheduleEventPresentation]

    var id: String { label }
}

// NOTE: @MainActor is intentional. SwiftData's ModelContext is not thread-safe
// and must be accessed from the actor it was created on. For the current dataset
// size (~90 pins, ~10 players), main-thread SwiftData ops have no measurable
// UI impact. If the dataset grows significantly, consider creating a background
// ModelContext via ModelContext(container) on a detached task.
@MainActor
final class ModelController: ObservableObject {
    /// Current local user profile loaded from SwiftData.
    @Published private(set) var currentUser: PlayerEntity?
    /// Campus pins used by map and AR entry points.
    @Published private(set) var pins: [PinEntity] = []
    /// Leaderboard data sorted by points.
    @Published private(set) var leaderboardUsers: [PlayerEntity] = []
    /// Event schedule source for schedule and event detail surfaces.
    @Published private(set) var scheduleEvents: [DatabaseEvent] = []
    /// All collectible definitions available to AR and collection flows.
    @Published private(set) var collectibleCatalog: [DatabaseCollectible] = []
    /// Primary map center resolved from config provider (backend-ready abstraction).
    @Published private(set) var campusCenter: CLLocationCoordinate2D
    @Published private(set) var addedScheduleEventIDs: Set<String> = []

    @Published private(set) var isSeedLoading = true
    @Published private(set) var startupErrorMessage: String?
    @Published private(set) var userFacingError: UserFacingErrorState?

    private(set) var modelContainer: ModelContainer?
    private var context: ModelContext?
    private let logger = AppLogger.make(.model)
    private let campusConfigProvider: CampusConfigProviding

    convenience init() {
        self.init(campusConfigProvider: CampusConfigProvider.active)
    }

    init(campusConfigProvider: CampusConfigProviding) {
        self.campusConfigProvider = campusConfigProvider
        self.campusCenter = campusConfigProvider.campusCenter
        initializeStore()
    }

    func clearUserFacingError() {
        userFacingError = nil
    }

    func retryInitialization() {
        initializeStore()
    }

    /// Resets in-memory state and attempts to re-open the local SwiftData store.
    /// This powers both first-launch setup and user-triggered retry from LaunchGateView.
    private func initializeStore() {
        isSeedLoading = true
        startupErrorMessage = nil
        userFacingError = nil
        currentUser = nil
        pins = []
        leaderboardUsers = []
        scheduleEvents = []
        collectibleCatalog = []
        addedScheduleEventIDs = []
        campusCenter = campusConfigProvider.campusCenter

        let schema = Schema([
            PlayerEntity.self,
            PinEntity.self,
            BadgeEntity.self,
            CollectedItemEntity.self
            ,SavedScheduleEventEntity.self
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
            publishStartupError(
                message: "Couldn't load offline data. Check device storage and try again.",
                context: "SwiftData container initialization",
                error: error
            )
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
                publishStartupError(
                    message: "Offline data is unavailable right now.",
                    context: "Load and seed guard"
                )
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
            startupErrorMessage = nil
        } catch {
            isSeedLoading = false
            publishStartupError(
                message: "Couldn't prepare offline data. Please retry.",
                context: "SwiftData load and seed",
                error: error
            )
        }
    }

    func refreshPublishedData() {
        guard let context else {
            publishRuntimeError(
                title: "Data unavailable",
                message: "Offline data is unavailable right now.",
                context: "Refresh published data without context"
            )
            return
        }

        do {
            let players = try context.fetch(FetchDescriptor<PlayerEntity>())
            let pins = try context.fetch(FetchDescriptor<PinEntity>())

            self.currentUser = players.first(where: { $0.isLocalUser })
            self.pins = pins
            self.leaderboardUsers = players.sorted { $0.totalPoints > $1.totalPoints }

            if let currentUser {
                let currentUserID = currentUser.id
                let savedDescriptor = FetchDescriptor<SavedScheduleEventEntity>(
                    predicate: #Predicate { item in
                        item.playerID == currentUserID
                    }
                )
                let savedEvents = try context.fetch(savedDescriptor)
                self.addedScheduleEventIDs = Set(savedEvents.map(\.eventID))
            } else {
                self.addedScheduleEventIDs = []
            }
        } catch {
            publishRuntimeError(
                title: "Couldn't refresh data",
                message: "Local data couldn't be refreshed. Some views may show stale values.",
                context: "SwiftData refresh",
                error: error
            )
        }
    }

    func captureCollectible(from pin: PinEntity, points: Int = 50) {
        if let collectible = preferredCollectible(for: pin) {
            captureCollectible(
                collectibleName: collectible.name,
                rarity: collectible.rarity,
                foundAtTitle: pin.title,
                points: collectible.points
            )
            return
        }

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
            publishRuntimeError(
                title: "Capture unavailable",
                message: "Offline data is unavailable right now.",
                context: "Capture collectible without context"
            )
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
            publishRuntimeError(
                title: "Capture failed",
                message: "Couldn't save collectible progress.",
                context: "Capture collectible save",
                error: error
            )
        }
    }

    func collectionItemsForCurrentUser() -> [CollectedItemEntity] {
        guard let user = currentUser else { return [] }
        guard let context else {
            publishRuntimeError(
                title: "Collection unavailable",
                message: "Offline data is unavailable right now.",
                context: "Load collection without context"
            )
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
            publishRuntimeError(
                title: "Collection unavailable",
                message: "Couldn't load collected items.",
                context: "Fetch collected items",
                error: error
            )
            return []
        }
    }

    func hasCollectedCollectible(named collectibleName: String) -> Bool {
        guard let user = currentUser else { return false }
        guard let context else {
            publishRuntimeError(
                title: "Collection check unavailable",
                message: "Offline data is unavailable right now.",
                context: "Check collected item without context"
            )
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
            publishRuntimeError(
                title: "Collection check failed",
                message: "Couldn't verify collectible progress.",
                context: "Verify collected item",
                error: error
            )
            return false
        }
    }

    func collectibles(for pin: PinEntity) -> [DatabaseCollectible] {
        let candidatesByID = pin.collectibleIDs.compactMap { collectibleID in
            collectibleCatalog.first(where: { $0.id == collectibleID })
        }

        if !candidatesByID.isEmpty {
            return candidatesByID
        }

        if let collectibleName = pin.collectibleName {
            return collectibleCatalog.filter { $0.name == collectibleName }
        }

        return []
    }

    func preferredCollectible(for pin: PinEntity, preferringUncollected: Bool = false) -> DatabaseCollectible? {
        let candidates = collectibles(for: pin)
        guard !candidates.isEmpty else { return nil }

        guard preferringUncollected else {
            return candidates.first
        }

        let collectedNames = Set(collectionItemsForCurrentUser().map(\.collectibleName))
        return candidates.first(where: { !collectedNames.contains($0.name) }) ?? candidates.first
    }

    func pin(for event: DatabaseEvent) -> PinEntity? {
        if let directRemoteMatch = pins.first(where: { $0.remoteEventID == event.id }) {
            return directRemoteMatch
        }

        if let exactTitleMatch = pins.first(where: { $0.title == event.title }) {
            return exactTitleMatch
        }

        return pins.first(where: { scheduleEventID(matchingPinTitle: $0.title) == event.id })
    }

    func availabilityState(for event: DatabaseEvent, now: Date = .now) -> PinAvailabilityState {
        guard let pin = pin(for: event) else {
            return .active
        }
        return pin.availabilityState(now: now)
    }

    func collectible(for event: DatabaseEvent) -> DatabaseCollectible? {
        if let pin = pin(for: event), let collectible = preferredCollectible(for: pin) {
            return collectible
        }

        guard let collectibleName = event.collectibleName else { return nil }
        return collectibleCatalog.first { $0.name == collectibleName }
    }

    func scheduleStatus(for event: DatabaseEvent, now: Date = .now) -> ScheduleEventStatus {
        let availability = availabilityState(for: event, now: now)
        let collectible = collectible(for: event)

        if collectible?.rarity == "Legendary", availability.isActive {
            return .featured
        }

        switch availability {
        case .active:
            return .active
        case .upcoming:
            return .upcoming
        case .ended:
            return .ended
        case .unavailable:
            return .unavailable
        }
    }

    func schedulePresentation(for event: DatabaseEvent, now: Date = .now) -> ScheduleEventPresentation {
        ScheduleEventPresentation(
            event: event,
            collectible: collectible(for: event),
            availability: availabilityState(for: event, now: now),
            status: scheduleStatus(for: event, now: now),
            isAdded: addedScheduleEventIDs.contains(event.id)
        )
    }

    func groupedScheduleSections(forDay day: Int, addedOnly: Bool, now: Date = .now) -> [ScheduleEventSection] {
        let baseEvents = scheduleEvents.filter { $0.dayNumber == day }
        let filteredEvents = addedOnly ? baseEvents.filter { addedScheduleEventIDs.contains($0.id) } : baseEvents
        let presentations = filteredEvents.map { schedulePresentation(for: $0, now: now) }

        var active: [ScheduleEventPresentation] = []
        var upcoming: [ScheduleEventPresentation] = []
        var unavailable: [ScheduleEventPresentation] = []
        var ended: [ScheduleEventPresentation] = []

        for presentation in presentations {
            switch presentation.status {
            case .active, .featured:
                active.append(presentation)
            case .upcoming:
                upcoming.append(presentation)
            case .unavailable:
                unavailable.append(presentation)
            case .ended:
                ended.append(presentation)
            }
        }

        var sections: [ScheduleEventSection] = []
        if !active.isEmpty {
            sections.append(ScheduleEventSection(label: "Available now", labelColor: .green, showsPulse: true, items: active))
        }
        if !upcoming.isEmpty {
            sections.append(ScheduleEventSection(label: "Available later", labelColor: .orange, showsPulse: false, items: upcoming))
        }
        if !unavailable.isEmpty {
            sections.append(ScheduleEventSection(label: "Unavailable", labelColor: .secondary, showsPulse: false, items: unavailable))
        }
        if !ended.isEmpty {
            sections.append(ScheduleEventSection(label: "Ended", labelColor: .secondary, showsPulse: false, items: ended))
        }
        if sections.isEmpty {
            sections.append(ScheduleEventSection(label: "Events", labelColor: .secondary, showsPulse: false, items: presentations))
        }
        return sections
    }

    func toggleEventAddedToSchedule(_ event: DatabaseEvent) {
        guard let currentUser else {
            publishRuntimeError(
                title: "Schedule unavailable",
                message: "Sign in to save events to your plan.",
                context: "Toggle saved schedule event without current user"
            )
            return
        }
        guard let context else {
            publishRuntimeError(
                title: "Schedule unavailable",
                message: "Offline data is unavailable right now.",
                context: "Toggle saved schedule event without context"
            )
            return
        }

        do {
            let currentUserID = currentUser.id
            let targetEventID = event.id
            let descriptor = FetchDescriptor<SavedScheduleEventEntity>(
                predicate: #Predicate { item in
                    item.playerID == currentUserID && item.eventID == targetEventID
                }
            )
            let existing = try context.fetch(descriptor)

            if existing.isEmpty {
                context.insert(SavedScheduleEventEntity(eventID: targetEventID, playerID: currentUserID))
            } else {
                existing.forEach(context.delete)
            }

            try context.save()
            refreshPublishedData()
        } catch {
            publishRuntimeError(
                title: "Couldn't update your plan",
                message: "The selected event could not be saved right now.",
                context: "Toggle saved schedule event",
                error: error
            )
        }
    }

    func featuredEventForHome(now: Date = .now) -> DatabaseEvent? {
        scheduleEvents.min { lhs, rhs in
            homeEventSortKey(for: lhs, now: now) < homeEventSortKey(for: rhs, now: now)
        }
    }

    func isPinCurrentlyAvailable(_ pin: PinEntity, now: Date = .now) -> Bool {
        pin.availabilityState(now: now).isActive
    }

    private func homeEventSortKey(for event: DatabaseEvent, now: Date) -> (Int, Int, Int, String) {
        let availabilityRank: Int
        switch availabilityState(for: event, now: now) {
        case .active:
            availabilityRank = 0
        case .upcoming:
            availabilityRank = 1
        case .unavailable:
            availabilityRank = 2
        case .ended:
            availabilityRank = 3
        }

        let rarityRank: Int
        switch collectible(for: event)?.rarity.lowercased() {
        case "legendary":
            rarityRank = 0
        case "epic":
            rarityRank = 1
        case "rare":
            rarityRank = 2
        case "common":
            rarityRank = 3
        default:
            rarityRank = 4
        }

        return (availabilityRank, rarityRank, event.dayNumber, event.id)
    }

    func updateCurrentUserAvatar(type: AvatarType, colorHex: String) {
        guard let user = currentUser else { return }
        guard let context else {
            publishRuntimeError(
                title: "Profile unavailable",
                message: "Offline data is unavailable right now.",
                context: "Avatar update without context"
            )
            return
        }
        user.avatarType = type
        user.avatarColorHex = colorHex

        do {
            try context.save()
            refreshPublishedData()
        } catch {
            publishRuntimeError(
                title: "Avatar update failed",
                message: "Couldn't save avatar changes.",
                context: "Save avatar update",
                error: error
            )
        }
    }

    /// Heuristic matcher that maps map pin titles to schedule event IDs.
    /// It checks exact normalized matches, then containment, then token overlap scoring.
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

    /// Normalizes text for resilient matching by lowercasing and stripping punctuation.
    private func normalizeForMatching(_ text: String) -> String {
        let lowered = text.lowercased()
        let cleaned = lowered.unicodeScalars.map { scalar -> Swift.Character in
            CharacterSet.alphanumerics.contains(scalar) ? Swift.Character(String(scalar)) : " "
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
                    collectibleRarity: pin.collectibleRarity,
                    collectibleIDs: pin.collectibleIDs
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

    private func publishStartupError(message: String, context: String, error: Error? = nil) {
        startupErrorMessage = message
        if let error {
            logger.error("\(context, privacy: .public): \(error.localizedDescription, privacy: .public)")
        } else {
            logger.error("\(context, privacy: .public): \(message, privacy: .public)")
        }
    }

    private func publishRuntimeError(title: String, message: String, context: String, error: Error? = nil) {
        userFacingError = UserFacingErrorState(title: title, message: message)
        if let error {
            logger.error("\(context, privacy: .public): \(error.localizedDescription, privacy: .public)")
        } else {
            logger.error("\(context, privacy: .public): \(message, privacy: .public)")
        }
    }

    // MARK: - Remote content integration

    /// Apply remote content from ContentService, replacing seed/fallback data where
    /// remote data is available. Remote pins are reconciled by stable remote ID;
    /// events and collectibles replace the in-memory arrays directly.
    func applyRemoteContent(from contentService: ContentService) {
        let seasonStart = contentService.currentSeason?.startsAt ?? AppConstants.Schedule.weekStart

        // Events: replace schedule if remote events are available
        if !contentService.remoteEvents.isEmpty {
            let remoteEvents = contentService.remoteEvents
                .map { $0.toDatabaseEvent(seasonStart: seasonStart) }
                .sorted { ($0.dayNumber, $0.timeRange) < ($1.dayNumber, $1.timeRange) }
            self.scheduleEvents = remoteEvents
            logger.info("Applied \(remoteEvents.count) remote events")
        }

        // Collectibles: replace catalog if remote collectibles are available
        if !contentService.remoteCollectibles.isEmpty {
            let remoteCatalog = contentService.remoteCollectibles
                .filter { $0.isActive ?? true }
                .map { $0.toDatabaseCollectible() }
            self.collectibleCatalog = remoteCatalog
            logger.info("Applied \(remoteCatalog.count) remote collectibles")
        }

        // Pins: upsert into SwiftData so the map reflects remote state
        if !contentService.remotePins.isEmpty {
            upsertRemotePins(contentService.remotePins)
        }

        // Campus center: update if remote config changed
        if let remoteConfig = contentService.remoteCampusConfig {
            campusCenter = CLLocationCoordinate2D(
                latitude: remoteConfig.centerLatitude,
                longitude: remoteConfig.centerLongitude
            )
        }
    }

    /// Upsert remote pins into SwiftData. Matches by title: updates existing pins
    /// and inserts new ones. Preserves locally-tracked collectible progress.
    private func upsertRemotePins(_ remotePins: [PinDTO]) {
        guard let context else {
            logger.warning("Cannot upsert remote pins: no SwiftData context")
            return
        }

        do {
            let existingPins = try context.fetch(FetchDescriptor<PinEntity>())
            let existingByRemoteID = Dictionary(uniqueKeysWithValues: existingPins.compactMap { pin in
                pin.remoteID.map { ($0, pin) }
            })
            let existingByTitle = Dictionary(uniqueKeysWithValues: existingPins.map { ($0.title, $0) })
            let latestRemoteIDs = Set(remotePins.map(\.id))

            for dto in remotePins {
                let existing = existingByRemoteID[dto.id] ?? existingByTitle[dto.title]

                if dto.isHidden ?? false {
                    if let existing {
                        context.delete(existing)
                    }
                    continue
                }

                if let existing {
                    apply(dto, to: existing)
                } else {
                    context.insert(dto.toPinEntity())
                }
            }

            for stalePin in existingPins {
                guard let remoteID = stalePin.remoteID else { continue }
                guard !latestRemoteIDs.contains(remoteID) else { continue }
                context.delete(stalePin)
            }

            try context.save()
            refreshPublishedData()
            logger.info("Upserted \(remotePins.count) remote pins")
        } catch {
            publishRuntimeError(
                title: "Pin sync issue",
                message: "Some map pins may not reflect the latest content.",
                context: "Remote pin upsert",
                error: error
            )
        }
    }

    private func apply(_ dto: PinDTO, to pin: PinEntity) {
        pin.remoteID = dto.id
        pin.remoteEventID = dto.eventId
        pin.pinType = PinType(rawValue: dto.pinType) ?? .site
        pin.title = dto.title
        pin.subtitle = dto.subtitle
        pin.latitude = dto.latitude
        pin.longitude = dto.longitude
        pin.pinDescription = dto.description
        pin.status = dto.status
        pin.hasARCollectible = dto.hasArCollectible ?? false
        pin.activationStartsAt = dto.activationStartsAt
        pin.activationEndsAt = dto.activationEndsAt
        pin.collectibleName = dto.collectibleName
        pin.collectibleRarity = dto.collectibleRarity
        pin.collectibleIDs = dto.collectibleIds ?? []
    }
}
