import Foundation
import SwiftUI

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
            return .green
        case .battle:
            return .orange
        case .homebase:
            return .indigo
        case .concert:
            return .purple
        }
    }
}

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
