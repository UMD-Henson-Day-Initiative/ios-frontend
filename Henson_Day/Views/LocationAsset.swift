// LocationAsset.swift

import Foundation
import CoreLocation

/// Represents a campus location, AR portal, character spot, or event node anchor on the map.
struct LocationAsset: Identifiable, Codable, Equatable {
    enum AssetType: String, Codable, CaseIterable {
        case statue
        case building
        case arPortal
        case character
        case eventNode
        case site
    }

    struct MediaRefs: Codable, Equatable {
        var thumbnailImageName: String?
        var arModelFileName: String?
        var audioFileName: String?
    }

    let id: UUID
    var name: String
    var buildingName: String?
    var gpsCoordinate: Coordinate
    /// For clustering/zoom level hints on the map UI.
    var mapRegionHint: String?
    var assetType: AssetType
    var narrativeNodeIDs: [UUID]
    /// Unlock conditions such as visited prerequisites or min progress flags.
    var unlockRequirements: UnlockRequirements?
    var mediaRefs: MediaRefs?

    init(
        id: UUID = UUID(),
        name: String,
        buildingName: String? = nil,
        gpsCoordinate: Coordinate,
        mapRegionHint: String? = nil,
        assetType: AssetType,
        narrativeNodeIDs: [UUID] = [],
        unlockRequirements: UnlockRequirements? = nil,
        mediaRefs: MediaRefs? = nil
    ) {
        self.id = id
        self.name = name
        self.buildingName = buildingName
        self.gpsCoordinate = gpsCoordinate
        self.mapRegionHint = mapRegionHint
        self.assetType = assetType
        self.narrativeNodeIDs = narrativeNodeIDs
        self.unlockRequirements = unlockRequirements
        self.mediaRefs = mediaRefs
    }
}

/// Minimal coordinate container to keep JSON light and platform-neutral.
struct Coordinate: Codable, Equatable {
    var latitude: Double
    var longitude: Double
}

/// Rules to unlock a LocationAsset.
struct UnlockRequirements: Codable, Equatable {
    /// Assets that must have been visited.
    var visitedOtherAssetIDs: [UUID]?
    /// Minimum progress marker (e.g., a chapter number or flag key).
    var minProgress: Int?
}
