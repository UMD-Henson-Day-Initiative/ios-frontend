import Foundation
import SwiftUI

/// The six categories of map pins, each with a distinct color and SF Symbol.
/// Used by both the map annotations and the pin detail bottom sheet.
enum PinType: String, Codable, CaseIterable {
    case site
    case event
    case collectible
    case battle
    case homebase
    case concert

    var displayLabel: String {
        switch self {
        case .site:
            return "Site"
        case .event:
            return "Event"
        case .collectible:
            return "Collectible"
        case .battle:
            return "Battle"
        case .homebase:
            return "Homebase"
        case .concert:
            return "Concert"
        }
    }

    var headerColor: Color {
        switch self {
        case .site:
            return .blue
        case .event:
            return .red
        case .collectible:
            return .yellow
        case .battle:
            return .purple
        case .homebase:
            return .green
        case .concert:
            return .orange
        }
    }

    var mapMarkerColor: Color {
        headerColor
    }

    var icon: String {
        switch self {
        case .site:        return "building.2.fill"
        case .event:       return "star.fill"
        case .collectible: return "cube.fill"
        case .battle:      return "bolt.fill"
        case .homebase:    return "house.fill"
        case .concert:     return "music.note"
        }
    }
}

/// View-model that bridges a `PinEntity` (SwiftData) to `PinDetailBottomSheet`.
/// Created on-the-fly by `MapScreen.detailForPin(_:)` — not persisted.
struct MapPinDetail: Identifiable, Equatable {
    let id: String
    let pinType: PinType
    let title: String
    let dayLabel: String?
    let timeRange: String?
    let locationName: String
    let description: String
    let collectibleName: String?
    let collectibleRarity: String?
    let hasARCollectible: Bool

    var metadataLine: String {
        var values: [String] = []

        if let dayLabel, !dayLabel.isEmpty {
            values.append(dayLabel)
        }
        if let timeRange, !timeRange.isEmpty {
            values.append(timeRange)
        }
        if !locationName.isEmpty {
            values.append(locationName)
        }

        return values.joined(separator: " • ")
    }
}
