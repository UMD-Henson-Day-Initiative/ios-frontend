import Foundation
import SwiftData

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

@Model
final class PlayerEntity {
    @Attribute(.unique) var id: UUID
    var displayName: String
    var avatarColorHex: String
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

    var avatarType: AvatarType {
        get { AvatarType(rawValue: avatarTypeRaw) ?? .turtle }
        set { avatarTypeRaw = newValue.rawValue }
    }
}

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

@Model
final class PinEntity {
    @Attribute(.unique) var id: UUID
    var pinTypeRaw: String
    var title: String
    var subtitle: String?
    var latitude: Double
    var longitude: Double
    var pinDescription: String
    var hasARCollectible: Bool
    var collectibleName: String?
    var collectibleRarity: String?

    init(
        id: UUID = UUID(),
        pinType: PinType,
        title: String,
        subtitle: String? = nil,
        latitude: Double,
        longitude: Double,
        pinDescription: String,
        hasARCollectible: Bool = false,
        collectibleName: String? = nil,
        collectibleRarity: String? = nil
    ) {
        self.id = id
        self.pinTypeRaw = pinType.rawValue
        self.title = title
        self.subtitle = subtitle
        self.latitude = latitude
        self.longitude = longitude
        self.pinDescription = pinDescription
        self.hasARCollectible = hasARCollectible
        self.collectibleName = collectibleName
        self.collectibleRarity = collectibleRarity
    }

    var pinType: PinType {
        get { PinType(rawValue: pinTypeRaw) ?? .site }
        set { pinTypeRaw = newValue.rawValue }
    }
}

@Model
final class CollectedItemEntity {
    @Attribute(.unique) var id: UUID
    var collectibleName: String
    var rarity: String
    var foundAtTitle: String
    var foundAtDate: Date

    var player: PlayerEntity?

    init(
        id: UUID = UUID(),
        collectibleName: String,
        rarity: String,
        foundAtTitle: String,
        foundAtDate: Date = .now,
        player: PlayerEntity? = nil
    ) {
        self.id = id
        self.collectibleName = collectibleName
        self.rarity = rarity
        self.foundAtTitle = foundAtTitle
        self.foundAtDate = foundAtDate
        self.player = player
    }
}
