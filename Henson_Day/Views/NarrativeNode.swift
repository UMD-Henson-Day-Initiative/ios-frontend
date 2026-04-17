// NarrativeNode.swift

import Foundation

/// A node in a branching narrative graph.
struct NarrativeNode: Identifiable, Codable, Equatable {
    enum NodeType: String, Codable, CaseIterable {
        case intro
        case lore
        case prompt
        case transition
        case completion
    }

    let id: UUID
    var title: String
    var bodyText: String
    var associatedLocationID: UUID?
    var associatedCharacterID: UUID?
    var nodeType: NodeType
    var nextNodeIDs: [UUID]
    var conditions: NarrativeConditions?

    init(
        id: UUID = UUID(),
        title: String,
        bodyText: String,
        associatedLocationID: UUID? = nil,
        associatedCharacterID: UUID? = nil,
        nodeType: NodeType,
        nextNodeIDs: [UUID] = [],
        conditions: NarrativeConditions? = nil
    ) {
        self.id = id
        self.title = title
        self.bodyText = bodyText
        self.associatedLocationID = associatedLocationID
        self.associatedCharacterID = associatedCharacterID
        self.nodeType = nodeType
        self.nextNodeIDs = nextNodeIDs
        self.conditions = conditions
    }
}

/// Conditions that gate whether a NarrativeNode is eligible.
struct NarrativeConditions: Codable, Equatable {
    var timeOfDay: TimeOfDayCondition?
    var scheduleSlotFilled: Bool?
    var previousNodeCompletedIDs: [UUID]?
}

enum TimeOfDayCondition: String, Codable, CaseIterable {
    case morning
    case afternoon
    case evening
    case night
}
