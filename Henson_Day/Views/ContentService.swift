// ContentService.swift

import Foundation
import Combine
import os

/// Central content repository. Loads from bundle JSON as fallback, prefers remote
/// content when the environment has `useRemoteContent` enabled. Views observe
/// published properties; sync state is exposed so LaunchGateView can show progress.
@MainActor
final class ContentService: ObservableObject {
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

    // MARK: - Sync metadata
    @Published private(set) var lastSuccessfulSyncAt: Date?
    @Published private(set) var contentVersion: String?
    @Published private(set) var syncState: ContentSyncState = .idle

    enum ContentSyncState: Equatable {
        case idle
        case loadingBundle
        case syncingRemote
        case synced
        case bundleOnly
        case failed(String)
        case stale
    }

    private let apiClient: APIClient?
    private let environment: AppEnvironment
    private let logger = Logger(subsystem: "HensonDay", category: "ContentSync")

    init(environment: AppEnvironment = .current) {
        self.environment = environment
        if environment.featureFlags.useRemoteContent {
            self.apiClient = APIClient(environment: environment)
        } else {
            self.apiClient = nil
        }
    }

    /// Full startup load: bundle first, then remote overlay if enabled.
    func loadContent() async {
        await loadFromBundle()
        if environment.featureFlags.useRemoteContent {
            await refreshFromRemote()
        } else {
            syncState = .bundleOnly
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

        if !environment.featureFlags.useRemoteContent {
            syncState = .bundleOnly
        }
    }

    /// Fetch remote content from the API. On failure, existing content remains.
    func refreshFromRemote() async {
        guard let apiClient else {
            logger.info("Remote content disabled for \(self.environment.name.rawValue, privacy: .public)")
            syncState = .bundleOnly
            return
        }

        syncState = .syncingRemote
        logger.info("Starting remote content sync")

        do {
            let bootstrap: BootstrapDTO = try await apiClient.get("/bootstrap")
            remoteCampusConfig = bootstrap.campusConfig
            contentVersion = bootstrap.contentVersion
            announcements = bootstrap.announcements

            var deltaQuery: [URLQueryItem]? = nil
            if let lastSync = lastSuccessfulSyncAt {
                deltaQuery = [URLQueryItem(name: "updatedAfter", value: ISO8601DateFormatter().string(from: lastSync))]
            }

            let events: [EventDTO] = try await apiClient.get("/events", queryItems: deltaQuery)
            remoteEvents = events

            let pins: [PinDTO] = try await apiClient.get("/pins", queryItems: deltaQuery)
            remotePins = pins

            let collectibles: [CollectibleDTO] = try await apiClient.get("/collectibles", queryItems: deltaQuery)
            remoteCollectibles = collectibles

            lastSuccessfulSyncAt = Date()
            syncState = .synced
            logger.info("Content sync complete. Version: \(bootstrap.contentVersion, privacy: .public), events: \(events.count), pins: \(pins.count), collectibles: \(collectibles.count)")
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
        case .synced, .bundleOnly, .stale, .failed:
            return true
        case .idle, .loadingBundle, .syncingRemote:
            return false
        }
    }

    // MARK: - Private

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
