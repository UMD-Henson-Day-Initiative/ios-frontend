import Foundation
import SwiftData

/// SwiftData persistent model definitions for the Henson Day app.
///
/// Each `@Model` class is a SwiftData entity stored in the shared `ModelContainer`.
/// Enum-typed properties (e.g. `avatarType`, `pinType`) cannot be stored directly by
/// SwiftData, so they are persisted as raw `String` values (e.g. `avatarTypeRaw`,
/// `pinTypeRaw`) with a computed property wrapper that converts to/from the enum.
///
/// Seeding of these entities at first launch is handled by `ModelController` using
/// the static values in `Database.swift`.

/// Avatar style choices available to each player. The `symbolName` maps each case
/// to a thematically matching SF Symbol for display in the UI.
enum AvatarType: String, Codable, CaseIterable {
    case turtle
    case fox
    case panda
    case owl
    case rabbit
    case bear
    case cat
    case dragon
    case eagle
    case otter

    var symbolName: String {
        switch self {
        case .turtle: return "tortoise.fill"
        case .fox: return "flame.fill"
        case .panda: return "pawprint.fill"
        case .owl: return "moon.stars.fill"
        case .rabbit: return "hare.fill"
        case .bear: return "shield.fill"
        case .cat: return "bolt.fill"
        case .dragon: return "sparkles"
        case .eagle: return "bird.fill"
        case .otter: return "drop.fill"
        }
    }
}

/// Represents a single participant in the scavenger hunt.
///
/// `isLocalUser` identifies the device owner; only one player should have this flag set.
/// `avatarTypeRaw` stores the `AvatarType` raw value because SwiftData cannot persist
/// custom enums directly — use the `avatarType` computed property instead.
/// The cascade-delete relationship ensures collected items are removed when the player is deleted.
@Model
final class PlayerEntity {
    @Attribute(.unique) var id: UUID
    var displayName: String
    var avatarColorHex: String
    /// Backing storage for `avatarType`. Do not read or write this directly in UI code.
    var avatarTypeRaw: String
    var totalPoints: Int
    var collectedCount: Int
    var isLocalUser: Bool

    @Relationship(deleteRule: .cascade, inverse: \CollectedItemEntity.player)
    var collectedItems: [CollectedItemEntity]

    init(
        id: UUID = UUID(),
        displayName: String,
        avatarColorHex: String,
        avatarType: AvatarType,
        totalPoints: Int,
        collectedCount: Int = 0,
        isLocalUser: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.avatarColorHex = avatarColorHex
        self.avatarTypeRaw = avatarType.rawValue
        self.totalPoints = totalPoints
        self.collectedCount = collectedCount
        self.isLocalUser = isLocalUser
        self.collectedItems = []
    }

    /// Type-safe accessor for the avatar selection. Falls back to `.turtle` if the stored
    /// raw value is unrecognized (e.g. after a data migration that adds a new case).
    var avatarType: AvatarType {
        get { AvatarType(rawValue: avatarTypeRaw) ?? .turtle }
        set { avatarTypeRaw = newValue.rawValue }
    }
}

/// An achievement badge that a player can earn during the event.
@Model
final class BadgeEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var badgeDescription: String
    var iconName: String

    init(id: UUID = UUID(), name: String, badgeDescription: String, iconName: String) {
        self.id = id
        self.name = name
        self.badgeDescription = badgeDescription
        self.iconName = iconName
    }
}

/// A geographic point of interest shown on the campus map.
///
/// `pinTypeRaw` is the String-backed storage for the `PinType` enum — use the `pinType`
/// computed property in UI code. Pins optionally link to an AR collectible; when
/// `hasARCollectible` is true, the pin can open `ARCollectibleExperienceView`.
@Model
final class PinEntity {
    @Attribute(.unique) var id: UUID
    /// Backing storage for `pinType`. Do not read or write this directly in UI code.
    var pinTypeRaw: String
    var remoteID: String?
    var remoteEventID: String?
    var title: String
    var subtitle: String?
    var latitude: Double
    var longitude: Double
    var pinDescription: String
    var status: String
    var hasARCollectible: Bool
    var activationStartsAt: Date?
    var activationEndsAt: Date?
    var collectibleName: String?
    var collectibleRarity: String?
    var collectibleIDsRaw: String

    init(
        id: UUID = UUID(),
        pinType: PinType,
        remoteID: String? = nil,
        remoteEventID: String? = nil,
        title: String,
        subtitle: String? = nil,
        latitude: Double,
        longitude: Double,
        pinDescription: String,
        status: String = "active",
        hasARCollectible: Bool = false,
        activationStartsAt: Date? = nil,
        activationEndsAt: Date? = nil,
        collectibleName: String? = nil,
        collectibleRarity: String? = nil,
        collectibleIDs: [String] = []
    ) {
        self.id = id
        self.pinTypeRaw = pinType.rawValue
        self.remoteID = remoteID
        self.remoteEventID = remoteEventID
        self.title = title
        self.subtitle = subtitle
        self.latitude = latitude
        self.longitude = longitude
        self.pinDescription = pinDescription
        self.status = status
        self.hasARCollectible = hasARCollectible
        self.activationStartsAt = activationStartsAt
        self.activationEndsAt = activationEndsAt
        self.collectibleName = collectibleName
        self.collectibleRarity = collectibleRarity
        self.collectibleIDsRaw = collectibleIDs.joined(separator: ",")
    }

    /// Type-safe accessor for the pin category. Falls back to `.site` for unrecognized values.
    var pinType: PinType {
        get { PinType(rawValue: pinTypeRaw) ?? .site }
        set { pinTypeRaw = newValue.rawValue }
    }

    var collectibleIDs: [String] {
        get {
            collectibleIDsRaw
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        set {
            collectibleIDsRaw = newValue
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: ",")
        }
    }
}

/// A record of a collectible that the local user has successfully captured via AR.
///
/// `playerID` is a denormalized copy of the owning player's UUID, retained alongside
/// the SwiftData relationship so that queries can filter by player without loading
/// the full `PlayerEntity` graph.
@Model
final class CollectedItemEntity {
    @Attribute(.unique) var id: UUID
    var collectibleID: String?
    var collectibleName: String
    var rarity: String
    var foundAtTitle: String
    var foundAtDate: Date
    var playerID: UUID

    var player: PlayerEntity?

    init(
        id: UUID = UUID(),
        collectibleID: String? = nil,
        collectibleName: String,
        rarity: String,
        foundAtTitle: String,
        foundAtDate: Date = .now,
        playerID: UUID,
        player: PlayerEntity? = nil
    ) {
        self.id = id
        self.collectibleID = collectibleID
        self.collectibleName = collectibleName
        self.rarity = rarity
        self.foundAtTitle = foundAtTitle
        self.foundAtDate = foundAtDate
        self.playerID = playerID
        self.player = player
    }
}

/// A locally saved schedule event that the current player has added to their plan.
@Model
final class SavedScheduleEventEntity {
    @Attribute(.unique) var id: UUID
    var eventID: String
    var playerID: UUID
    var addedAt: Date

    init(
        id: UUID = UUID(),
        eventID: String,
        playerID: UUID,
        addedAt: Date = .now
    ) {
        self.id = id
        self.eventID = eventID
        self.playerID = playerID
        self.addedAt = addedAt
    }
}
