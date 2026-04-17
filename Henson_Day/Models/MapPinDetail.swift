import Foundation
import SwiftUI

enum PinAvailabilityState: Equatable {
    case active
    case upcoming(message: String)
    case ended(message: String)
    case unavailable(message: String)

    var isActive: Bool {
        if case .active = self {
            return true
        }
        return false
    }

    var label: String {
        switch self {
        case .active:
            return "Available now"
        case .upcoming:
            return "Available later"
        case .ended:
            return "Ended"
        case .unavailable:
            return "Unavailable"
        }
    }

    var message: String? {
        switch self {
        case .active:
            return nil
        case .upcoming(let message), .ended(let message), .unavailable(let message):
            return message
        }
    }

    var tint: Color {
        switch self {
        case .active:
            return .green
        case .upcoming:
            return .orange
        case .ended, .unavailable:
            return .secondary
        }
    }

    var symbolName: String {
        switch self {
        case .active:
            return "checkmark.circle.fill"
        case .upcoming:
            return "clock.fill"
        case .ended:
            return "moon.zzz.fill"
        case .unavailable:
            return "slash.circle.fill"
        }
    }
}

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
    let availability: PinAvailabilityState
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

extension PinEntity {
    func availabilityState(now: Date = .now) -> PinAvailabilityState {
        let normalizedStatus = status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if ["cancelled", "disabled", "hidden", "inactive"].contains(normalizedStatus) {
            return .unavailable(message: "This stop is not active right now.")
        }

        if normalizedStatus == "ended" {
            return .ended(message: "This stop is no longer active.")
        }

        if normalizedStatus == "scheduled", let activationStartsAt, activationStartsAt > now {
            return .upcoming(message: availabilityMessage(prefix: "Opens", date: activationStartsAt))
        }

        if let activationStartsAt, activationStartsAt > now {
            return .upcoming(message: availabilityMessage(prefix: "Opens", date: activationStartsAt))
        }

        if let activationEndsAt, activationEndsAt < now {
            return .ended(message: availabilityMessage(prefix: "Closed", date: activationEndsAt))
        }

        return .active
    }

    private func availabilityMessage(prefix: String, date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "\(prefix) \(formatter.string(from: date))."
    }
}
