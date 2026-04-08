// ContentService.swift

import Foundation

/// Central content loader for assets, characters, and narrative graph.
@MainActor
final class ContentService: ObservableObject {
    @Published private(set) var locationAssets: [LocationAsset] = []
    @Published private(set) var characters: [Character] = []
    @Published private(set) var narrativeNodes: [NarrativeNode] = []

    /// Load from bundled JSON seeds. Call on app start.
    func loadFromBundle() async {
        do {
            self.locationAssets = try await loadJSON("LocationAssetsSeed.json")
        } catch {
            print("[ContentService] Failed to load LocationAssetsSeed.json: \(error)")
            self.locationAssets = []
        }

        do {
            self.characters = try await loadJSON("CharactersSeed.json")
        } catch {
            print("[ContentService] Failed to load CharactersSeed.json: \(error)")
            self.characters = []
        }

        do {
            self.narrativeNodes = try await loadJSON("NarrativeNodesSeed.json")
        } catch {
            print("[ContentService] Failed to load NarrativeNodesSeed.json: \(error)")
            self.narrativeNodes = []
        }
    }

    /// Placeholder for remote refresh (Supabase / Firestore / custom).
    func refreshFromRemoteIfAvailable() async {
        // TODO: Implement remote fetch and merge/migration logic.
        // Strategy:
        // 1) Fetch versioned payloads for assets/characters/nodes.
        // 2) Validate schema version.
        // 3) Merge into local store, preserving IDs.
        // 4) Publish updates.
    }

    /// Generic bundle JSON loader.
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
