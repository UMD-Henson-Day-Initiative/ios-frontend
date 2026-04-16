// ContentService.swift

import Foundation
import Combine
import os
import SwiftData

/// Central content repository. Loads from bundle JSON as fallback, prefers remote
/// content when the environment has `useRemoteContent` enabled. Views observe
/// published properties; sync state is exposed so LaunchGateView can show progress.
@MainActor
final class ContentService: ObservableObject {
    private enum SyncFetchMode {
        case full
        case delta
    }

    // MARK: - Bundle content (always available)
    @Published private(set) var locationAssets: [LocationAsset] = []
    @Published private(set) var characters: [Character] = []
    @Published private(set) var narrativeNodes: [NarrativeNode] = []

    // MARK: - Remote content (populated when remote sync succeeds)
    @Published private(set) var remoteEvents: [EventDTO] = []
    @Published private(set) var remotePins: [PinDTO] = []
    @Published private(set) var remoteCollectibles: [CollectibleDTO] = []
    @Published private(set) var announcements: [AnnouncementDTO] = []
    @Published private(set) var remoteCampusConfig: CampusConfigDTO?
    @Published private(set) var currentSeason: SeasonDTO?

    // MARK: - Sync metadata
    @Published private(set) var lastSuccessfulSyncAt: Date?
    @Published private(set) var contentVersion: String?
    @Published private(set) var syncState: ContentSyncState = .idle

    enum ContentSyncState: Equatable {
        case idle
        case loadingBundle
        case syncingRemote
        case synced
        case bundleOnly(String?)
        case failed(String)
        case stale
    }

    private let apiClient: APIClient?
    private let environment: AppEnvironment
    private let logger = AppLogger.make(.contentSync)
    private let isoFormatter = ISO8601DateFormatter()
    private let cacheContainer: ModelContainer?
    private let cacheContext: ModelContext?
    private var lastSuccessfulFullSyncAt: Date?
    private let fullRefreshInterval: TimeInterval = 60 * 60 * 6

    init(environment: AppEnvironment) {
        self.environment = environment
        if environment.usesRemoteContent {
            self.apiClient = APIClient(environment: environment)
        } else {
            self.apiClient = nil
        }
        let cacheStore = Self.makeCacheStore(logger: logger)
        self.cacheContainer = cacheStore.container
        self.cacheContext = cacheStore.context
    }

    var startupNotice: String? {
        environment.remoteContentDisabledReason
    }

    @discardableResult
    func restoreCachedRemoteContentIfAvailable() -> Bool {
        loadCachedRemoteContentIfAvailable()
        return hasRemoteOverlayContent
    }

    /// Full startup load: bundle first, then remote overlay if enabled.
    func loadContent() async {
        logger.info("Loading content for environment \(self.environment.name.rawValue, privacy: .public)")
        await loadFromBundle()
        _ = restoreCachedRemoteContentIfAvailable()
        if environment.usesRemoteContent {
            await refreshFromRemote()
        } else {
            syncState = .bundleOnly(environment.remoteContentDisabledReason)
        }
    }

    /// Load from bundled JSON seeds. Always succeeds with empty fallback per file.
    func loadFromBundle() async {
        syncState = .loadingBundle

        do {
            self.locationAssets = try await loadJSON("LocationAssetsSeed.json")
        } catch {
            logger.warning("Bundle load failed for LocationAssetsSeed.json: \(error.localizedDescription, privacy: .public)")
            self.locationAssets = []
        }

        do {
            self.characters = try await loadJSON("CharactersSeed.json")
        } catch {
            logger.warning("Bundle load failed for CharactersSeed.json: \(error.localizedDescription, privacy: .public)")
            self.characters = []
        }

        do {
            self.narrativeNodes = try await loadJSON("NarrativeNodesSeed.json")
        } catch {
            logger.warning("Bundle load failed for NarrativeNodesSeed.json: \(error.localizedDescription, privacy: .public)")
            self.narrativeNodes = []
        }

        if !environment.usesRemoteContent {
            syncState = .bundleOnly(environment.remoteContentDisabledReason)
        }
    }

    /// Fetch remote content from the API. On failure, existing content remains.
    func refreshFromRemote() async {
        guard let apiClient else {
            logger.info("Remote content disabled for \(self.environment.name.rawValue, privacy: .public)")
            syncState = .bundleOnly(environment.remoteContentDisabledReason)
            return
        }

        syncState = .syncingRemote
        logger.info("Starting remote content sync")

        do {
            let bootstrap: BootstrapDTO = try await apiClient.get("/bootstrap")
            let previousContentVersion = contentVersion
            let contentVersionChanged = previousContentVersion != nil && previousContentVersion != bootstrap.contentVersion
            let fetchMode = determineFetchMode(contentVersionChanged: contentVersionChanged)

            if contentVersionChanged {
                logger.info("Content version changed from \(previousContentVersion ?? "unknown", privacy: .public) to \(bootstrap.contentVersion, privacy: .public). Forcing full refresh.")
            }

            remoteCampusConfig = bootstrap.campusConfig
            currentSeason = bootstrap.currentSeason
            contentVersion = bootstrap.contentVersion
            announcements = bootstrap.announcements

            var deltaQuery: [URLQueryItem]? = nil
            if fetchMode == .delta, let lastSync = lastSuccessfulSyncAt {
                deltaQuery = [URLQueryItem(name: "updatedAfter", value: isoFormatter.string(from: lastSync))]
            }

            let fetchedEvents: [EventDTO] = try await apiClient.get("/events", queryItems: deltaQuery)
            let resolvedEvents: [EventDTO]
            if fetchMode == .full {
                resolvedEvents = fetchedEvents.sorted { $0.id < $1.id }
            } else {
                resolvedEvents = merge(existing: remoteEvents, updates: fetchedEvents, id: \.id)
            }
            remoteEvents = resolvedEvents

            let fetchedPins: [PinDTO] = try await apiClient.get("/pins", queryItems: deltaQuery)
            let resolvedPins: [PinDTO]
            if fetchMode == .full {
                resolvedPins = fetchedPins.sorted { $0.id < $1.id }
            } else {
                resolvedPins = merge(existing: remotePins, updates: fetchedPins, id: \.id)
            }
            remotePins = resolvedPins

            let fetchedCollectibles: [CollectibleDTO] = try await apiClient.get("/collectibles", queryItems: deltaQuery)
            let resolvedCollectibles: [CollectibleDTO]
            if fetchMode == .full {
                resolvedCollectibles = fetchedCollectibles.sorted { $0.id < $1.id }
            } else {
                resolvedCollectibles = merge(existing: remoteCollectibles, updates: fetchedCollectibles, id: \.id)
            }
            remoteCollectibles = resolvedCollectibles

            let syncDate = Date()
            lastSuccessfulSyncAt = syncDate
            if fetchMode == .full {
                lastSuccessfulFullSyncAt = syncDate
            }
            persistRemoteContentCache(
                bootstrap: bootstrap,
                events: resolvedEvents,
                pins: resolvedPins,
                collectibles: resolvedCollectibles,
                mode: fetchMode,
                syncDate: syncDate
            )
            syncState = .synced
            logger.info("Content sync complete using \(fetchMode == .full ? "full" : "delta", privacy: .public) refresh. Version: \(bootstrap.contentVersion, privacy: .public), events: \(resolvedEvents.count), pins: \(resolvedPins.count), collectibles: \(resolvedCollectibles.count)")
        } catch {
            let message = error.localizedDescription
            if lastSuccessfulSyncAt != nil {
                syncState = .stale
                logger.warning("Content sync failed, using stale data: \(message, privacy: .public)")
            } else {
                syncState = .failed(message)
                logger.error("Content sync failed with no prior data: \(message, privacy: .public)")
            }
        }
    }

    /// True when remote content was last synced more than 1 hour ago.
    var isContentStale: Bool {
        guard let lastSync = lastSuccessfulSyncAt else { return false }
        return Date().timeIntervalSince(lastSync) > 3600
    }

    /// Whether the service has any usable content (bundle or remote).
    var hasUsableContent: Bool {
        switch syncState {
        case .synced, .bundleOnly(_), .stale, .failed:
            return true
        case .syncingRemote:
            return hasRemoteOverlayContent
        case .idle, .loadingBundle:
            return false
        }
    }

    var hasRemoteOverlayContent: Bool {
        remoteCampusConfig != nil || currentSeason != nil || !remoteEvents.isEmpty || !remotePins.isEmpty || !remoteCollectibles.isEmpty || !announcements.isEmpty
    }

    // MARK: - Private

    private static func makeCacheStore(logger: Logger) -> (container: ModelContainer?, context: ModelContext?) {
        let schema = Schema([
            CachedContentMetadataEntity.self,
            CachedCampusConfigEntity.self,
            CachedSeasonEntity.self,
            CachedEventEntity.self,
            CachedPinEntity.self,
            CachedCollectibleEntity.self,
            CachedAnnouncementEntity.self,
        ])

        let config = ModelConfiguration("HensonDayRemoteCache", schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            return (container, ModelContext(container))
        } catch {
            logger.error("Failed to initialize remote cache store: \(error.localizedDescription, privacy: .public)")
            return (nil, nil)
        }
    }

    private func loadCachedRemoteContentIfAvailable() {
        guard let cacheContext else { return }

        do {
            let metadata = try cacheContext.fetch(FetchDescriptor<CachedContentMetadataEntity>()).first
            let campusConfigEntity = try cacheContext.fetch(FetchDescriptor<CachedCampusConfigEntity>()).first
            let seasonEntity = try cacheContext.fetch(FetchDescriptor<CachedSeasonEntity>()).first
            let eventEntities = try cacheContext.fetch(FetchDescriptor<CachedEventEntity>())
            let pinEntities = try cacheContext.fetch(FetchDescriptor<CachedPinEntity>())
            let collectibleEntities = try cacheContext.fetch(FetchDescriptor<CachedCollectibleEntity>())
            let announcementEntities = try cacheContext.fetch(FetchDescriptor<CachedAnnouncementEntity>())

            if let metadata {
                contentVersion = metadata.contentVersion
                lastSuccessfulSyncAt = metadata.lastSuccessfulSyncAt == .distantPast ? nil : metadata.lastSuccessfulSyncAt
                lastSuccessfulFullSyncAt = metadata.lastSuccessfulFullSyncAt == .distantPast ? nil : metadata.lastSuccessfulFullSyncAt
            }
            remoteCampusConfig = campusConfigEntity.map(CampusConfigDTO.init)
            currentSeason = seasonEntity.map(SeasonDTO.init)
            remoteEvents = eventEntities.map(EventDTO.init)
            remotePins = pinEntities.map(PinDTO.init)
            remoteCollectibles = collectibleEntities.map(CollectibleDTO.init)
            announcements = announcementEntities.map(AnnouncementDTO.init)

            if metadata != nil || campusConfigEntity != nil || !eventEntities.isEmpty || !pinEntities.isEmpty || !collectibleEntities.isEmpty || !announcementEntities.isEmpty {
                logger.info("Loaded cached remote content. Events: \(eventEntities.count), pins: \(pinEntities.count), collectibles: \(collectibleEntities.count), announcements: \(announcementEntities.count)")
            }
        } catch {
            logger.warning("Failed to load cached remote content: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func persistRemoteContentCache(
        bootstrap: BootstrapDTO,
        events: [EventDTO],
        pins: [PinDTO],
        collectibles: [CollectibleDTO],
        mode: SyncFetchMode,
        syncDate: Date
    ) {
        guard let cacheContext else { return }

        do {
            let metadata = try cacheContext.fetch(FetchDescriptor<CachedContentMetadataEntity>()).first ?? CachedContentMetadataEntity()
            metadata.contentVersion = bootstrap.contentVersion
            metadata.lastSuccessfulSyncAt = syncDate
            if mode == .full {
                metadata.lastSuccessfulFullSyncAt = syncDate
            }
            if metadata.modelContext == nil {
                cacheContext.insert(metadata)
            }

            let cachedCampusConfig = try cacheContext.fetch(FetchDescriptor<CachedCampusConfigEntity>()).first ?? CachedCampusConfigEntity()
            cachedCampusConfig.apply(bootstrap.campusConfig)
            if cachedCampusConfig.modelContext == nil {
                cacheContext.insert(cachedCampusConfig)
            }

            let existingSeasonEntities = try cacheContext.fetch(FetchDescriptor<CachedSeasonEntity>())
            if let currentSeason = bootstrap.currentSeason {
                if let cachedSeason = existingSeasonEntities.first(where: { $0.id == currentSeason.id }) {
                    cachedSeason.apply(currentSeason)
                } else {
                    cacheContext.insert(CachedSeasonEntity(dto: currentSeason))
                }
                for staleSeason in existingSeasonEntities where staleSeason.id != currentSeason.id {
                    cacheContext.delete(staleSeason)
                }
            } else {
                for season in existingSeasonEntities {
                    cacheContext.delete(season)
                }
            }

            if mode == .full {
                replace(events, existing: try cacheContext.fetch(FetchDescriptor<CachedEventEntity>()), context: cacheContext)
                replace(pins, existing: try cacheContext.fetch(FetchDescriptor<CachedPinEntity>()), context: cacheContext)
                replace(collectibles, existing: try cacheContext.fetch(FetchDescriptor<CachedCollectibleEntity>()), context: cacheContext)
            } else {
                upsert(events, existing: try cacheContext.fetch(FetchDescriptor<CachedEventEntity>()), context: cacheContext)
                upsert(pins, existing: try cacheContext.fetch(FetchDescriptor<CachedPinEntity>()), context: cacheContext)
                upsert(collectibles, existing: try cacheContext.fetch(FetchDescriptor<CachedCollectibleEntity>()), context: cacheContext)
            }
            replace(bootstrap.announcements, existing: try cacheContext.fetch(FetchDescriptor<CachedAnnouncementEntity>()), context: cacheContext)

            try cacheContext.save()
        } catch {
            logger.warning("Failed to persist remote content cache: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func determineFetchMode(contentVersionChanged: Bool) -> SyncFetchMode {
        if contentVersionChanged {
            return .full
        }
        if !hasRemoteOverlayContent {
            return .full
        }
        guard let lastSuccessfulFullSyncAt else {
            return .full
        }
        if Date().timeIntervalSince(lastSuccessfulFullSyncAt) >= fullRefreshInterval {
            return .full
        }
        return .delta
    }

    private func merge<T>(existing: [T], updates: [T], id: KeyPath<T, String>) -> [T] {
        guard !updates.isEmpty else { return existing }
        var mergedByID = Dictionary(uniqueKeysWithValues: existing.map { ($0[keyPath: id], $0) })
        for update in updates {
            mergedByID[update[keyPath: id]] = update
        }
        return mergedByID.values.sorted { $0[keyPath: id] < $1[keyPath: id] }
    }

    private func upsert(_ items: [EventDTO], existing: [CachedEventEntity], context: ModelContext) {
        let existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        for item in items {
            if let existingEntity = existingByID[item.id] {
                existingEntity.apply(item)
            } else {
                context.insert(CachedEventEntity(dto: item))
            }
        }
    }

    private func upsert(_ items: [PinDTO], existing: [CachedPinEntity], context: ModelContext) {
        let existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        for item in items {
            if let existingEntity = existingByID[item.id] {
                existingEntity.apply(item)
            } else {
                context.insert(CachedPinEntity(dto: item))
            }
        }
    }

    private func upsert(_ items: [CollectibleDTO], existing: [CachedCollectibleEntity], context: ModelContext) {
        let existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        for item in items {
            if let existingEntity = existingByID[item.id] {
                existingEntity.apply(item)
            } else {
                context.insert(CachedCollectibleEntity(dto: item))
            }
        }
    }

    private func upsert(_ items: [AnnouncementDTO], existing: [CachedAnnouncementEntity], context: ModelContext) {
        let existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        for item in items {
            if let existingEntity = existingByID[item.id] {
                existingEntity.apply(item)
            } else {
                context.insert(CachedAnnouncementEntity(dto: item))
            }
        }
    }

    private func replace(_ items: [EventDTO], existing: [CachedEventEntity], context: ModelContext) {
        let incomingIDs = Set(items.map(\.id))
        for entity in existing where !incomingIDs.contains(entity.id) {
            context.delete(entity)
        }
        upsert(items, existing: existing.filter { incomingIDs.contains($0.id) }, context: context)
    }

    private func replace(_ items: [PinDTO], existing: [CachedPinEntity], context: ModelContext) {
        let incomingIDs = Set(items.map(\.id))
        for entity in existing where !incomingIDs.contains(entity.id) {
            context.delete(entity)
        }
        upsert(items, existing: existing.filter { incomingIDs.contains($0.id) }, context: context)
    }

    private func replace(_ items: [CollectibleDTO], existing: [CachedCollectibleEntity], context: ModelContext) {
        let incomingIDs = Set(items.map(\.id))
        for entity in existing where !incomingIDs.contains(entity.id) {
            context.delete(entity)
        }
        upsert(items, existing: existing.filter { incomingIDs.contains($0.id) }, context: context)
    }

    private func replace(_ items: [AnnouncementDTO], existing: [CachedAnnouncementEntity], context: ModelContext) {
        let incomingIDs = Set(items.map(\.id))
        for entity in existing where !incomingIDs.contains(entity.id) {
            context.delete(entity)
        }
        upsert(items, existing: existing.filter { incomingIDs.contains($0.id) }, context: context)
    }

    private func loadJSON<T: Decodable>(_ fileName: String) async throws -> T {
        try await Task.detached(priority: .userInitiated) {
            guard let url = Bundle.main.url(forResource: fileName, withExtension: nil) else {
                throw NSError(domain: "ContentService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing bundle file: \(fileName)"])
            }
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(T.self, from: data)
        }.value
    }
}
