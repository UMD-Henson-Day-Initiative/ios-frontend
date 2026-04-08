// Character.swift

import Foundation

/// Represents an in-world character that can interact with the user.
struct Character: Identifiable, Codable, Equatable {
    enum PersonalityTrait: String, Codable, CaseIterable {
        case playful
        case mentor
        case cryptic
        case curious
        case excited
        case chill
    }

    enum InteractionType: String, Codable, CaseIterable {
        case riddle
        case trivia
        case hideAndSeek
        case infoBlurb
        case navigationHint
    }

    let id: UUID
    var name: String
    /// Reference to a 2D sprite or 3D model in the app bundle.
    var avatarAssetRef: String?
    var personalityTraits: [PersonalityTrait]
    var supportedInteractionTypes: [InteractionType]

    init(
        id: UUID = UUID(),
        name: String,
        avatarAssetRef: String? = nil,
        personalityTraits: [PersonalityTrait] = [],
        supportedInteractionTypes: [InteractionType] = []
    ) {
        self.id = id
        self.name = name
        self.avatarAssetRef = avatarAssetRef
        self.personalityTraits = personalityTraits
        self.supportedInteractionTypes = supportedInteractionTypes
    }
}
