import Foundation
import CoreLocation

struct DatabasePlayerSeed {
    let displayName: String
    let avatarColorHex: String
    let avatarType: AvatarType
    let totalPoints: Int
    let collectedCount: Int
    let isLocalUser: Bool
}

struct DatabasePinSeed {
    let pinType: PinType
    let title: String
    let subtitle: String?
    let latitude: Double
    let longitude: Double
    let description: String
    let hasARCollectible: Bool
    let collectibleName: String?
    let collectibleRarity: String?
    // IDs of collectibles that are allowed to spawn at this pin.
    let collectibleIDs: [String]
}

struct DatabaseEvent: Identifiable {
    let id: String
    let dayNumber: Int
    let title: String
    let timeRange: String
    let locationName: String
    let description: String
    let pinType: PinType
    let collectibleName: String?

    var metadataLine: String {
        "Day \(dayNumber) • \(timeRange) • \(locationName)"
    }
}

struct DatabaseCollectible: Identifiable {
    let id: String
    let name: String
    let rarity: String
    // Human-readable location for where this collectible belongs.
    let location: String
    // File name in /3DModels used when spawning in AR.
    let modelFileName: String
    let points: Int
}

enum Database {
    static let campusCenter = CLLocationCoordinate2D(latitude: 38.9869, longitude: -76.9426)

    static let players: [DatabasePlayerSeed] = [
        .init(displayName: "You", avatarColorHex: "#D7263D", avatarType: .turtle, totalPoints: 240, collectedCount: 0, isLocalUser: true),
        .init(displayName: "Avery", avatarColorHex: "#2D7FF9", avatarType: .fox, totalPoints: 410, collectedCount: 4, isLocalUser: false),
        .init(displayName: "Jordan", avatarColorHex: "#5F6BFF", avatarType: .panda, totalPoints: 360, collectedCount: 3, isLocalUser: false),
        .init(displayName: "Sam", avatarColorHex: "#0D9488", avatarType: .owl, totalPoints: 335, collectedCount: 3, isLocalUser: false),
        .init(displayName: "Taylor", avatarColorHex: "#F59E0B", avatarType: .rabbit, totalPoints: 290, collectedCount: 2, isLocalUser: false),
        .init(displayName: "Morgan", avatarColorHex: "#22C55E", avatarType: .bear, totalPoints: 265, collectedCount: 2, isLocalUser: false),
        .init(displayName: "Riley", avatarColorHex: "#A855F7", avatarType: .cat, totalPoints: 250, collectedCount: 2, isLocalUser: false),
        .init(displayName: "Casey", avatarColorHex: "#EC4899", avatarType: .dragon, totalPoints: 230, collectedCount: 1, isLocalUser: false),
        .init(displayName: "Quinn", avatarColorHex: "#64748B", avatarType: .eagle, totalPoints: 220, collectedCount: 1, isLocalUser: false),
        .init(displayName: "Parker", avatarColorHex: "#14B8A6", avatarType: .otter, totalPoints: 205, collectedCount: 1, isLocalUser: false)
    ]

    static let events: [DatabaseEvent] = [
        .init(id: "event-1", dayNumber: 1, title: "Stadium Spirit Rally", timeRange: "5:00 PM – 7:00 PM", locationName: "Maryland Stadium", description: "Show your Terp pride at the opening rally, featuring music and performances.", pinType: .event, collectibleName: "Stadium Stomper"),
        .init(id: "event-2", dayNumber: 1, title: "McKeldin Time Capsule Hunt", timeRange: "2:30 PM – 4:00 PM", locationName: "McKeldin Mall", description: "Follow clues to unlock hidden AR collectibles around the mall.", pinType: .collectible, collectibleName: "Mall Muppet"),
        .init(id: "event-3", dayNumber: 2, title: "Terp Team Battle", timeRange: "3:00 PM – 4:00 PM", locationName: "Stamp Student Union", description: "Compete in a friendly AR battle challenge for bonus points.", pinType: .battle, collectibleName: nil),
        .init(id: "event-4", dayNumber: 2, title: "Idea Lab Showcase", timeRange: "1:00 PM – 2:30 PM", locationName: "Idea Factory", description: "Explore student projects and collect showcase-only items.", pinType: .site, collectibleName: nil),
        .init(id: "event-5", dayNumber: 3, title: "Evening Concert", timeRange: "7:30 PM – 9:00 PM", locationName: "Chapel Field", description: "Live music with a limited-time AR collectible drop.", pinType: .concert, collectibleName: "Soundwave Snare"),
        .init(id: "event-6", dayNumber: 4, title: "Henson Homebase Daily Check-In", timeRange: "10:00 AM – 8:00 PM", locationName: "Hornbake Plaza", description: "Stop by Homebase to claim perks and hints for nearby collectibles.", pinType: .homebase, collectibleName: nil),
        .init(id: "event-7", dayNumber: 5, title: "Quantum Courtyard Pop-Up", timeRange: "12:00 PM – 1:30 PM", locationName: "IRB Courtyard", description: "Short-form AR activity with bonus points for fast captures.", pinType: .event, collectibleName: "Quantum Smth"),
        .init(id: "event-8", dayNumber: 6, title: "Terrapin Twilight Run", timeRange: "6:30 PM – 8:00 PM", locationName: "Lot 1 Loop", description: "A campus run with geo-tagged AR checkpoints.", pinType: .site, collectibleName: nil),
        .init(id: "event-9", dayNumber: 7, title: "Finale Badge Sprint", timeRange: "4:00 PM – 6:00 PM", locationName: "McKeldin Steps", description: "Last chance to complete collections and earn final badges.", pinType: .battle, collectibleName: "Finale Flare")
    ]

    static let collectibleCatalog: [DatabaseCollectible] = [
        .init(id: "c1", name: "Stadium Stomper", rarity: "Rare", location: "Maryland Stadium", modelFileName: "robot", points: 50),
        .init(id: "c2", name: "Mall Muppet", rarity: "Common", location: "McKeldin Mall", modelFileName: "toy_car", points: 40),
        .init(id: "c3", name: "Soundwave Snare", rarity: "Rare", location: "Chapel Field", modelFileName: "hummingbird_anim", points: 55),
        .init(id: "c4", name: "Quantum Smth", rarity: "Legendary", location: "IRB Courtyard", modelFileName: "toy_biplane_realistic", points: 75),
        .init(id: "c5", name: "Finale Flare", rarity: "Legendary", location: "McKeldin Steps", modelFileName: "slide", points: 100)
    ]

    static let pins: [DatabasePinSeed] = [
        .init(pinType: .event, title: "Stadium Spirit Rally", subtitle: "Day 1 • 5:00 PM – 7:00 PM • Maryland Stadium", latitude: 38.9903, longitude: -76.9457, description: "Show your Terp pride at the opening rally, featuring music and performances.", hasARCollectible: true, collectibleName: "Stadium Stomper", collectibleRarity: "Rare", collectibleIDs: ["c1"]),
        .init(pinType: .collectible, title: "McKeldin Time Capsule", subtitle: "Day 1 • 2:30 PM – 4:00 PM • McKeldin Mall", latitude: 38.9857, longitude: -76.9456, description: "A hidden AR collectible near the center of the mall.", hasARCollectible: true, collectibleName: "Mall Muppet", collectibleRarity: "Common", collectibleIDs: ["c2"]),
        .init(pinType: .battle, title: "Terp Team Battle", subtitle: "Day 2 • 3:00 PM – 4:00 PM • Stamp Student Union", latitude: 38.9881, longitude: -76.9447, description: "Start a friendly AR faceoff and earn bonus points.", hasARCollectible: false, collectibleName: nil, collectibleRarity: nil, collectibleIDs: []),
        .init(pinType: .homebase, title: "Henson Homebase", subtitle: "Day 4 • 10:00 AM – 8:00 PM • Hornbake Plaza", latitude: 38.9889, longitude: -76.9418, description: "Check in to collect daily perks and hints.", hasARCollectible: false, collectibleName: nil, collectibleRarity: nil, collectibleIDs: []),
        .init(pinType: .concert, title: "Evening Concert", subtitle: "Day 3 • 7:30 PM – 9:00 PM • Chapel Field", latitude: 38.9878, longitude: -76.9392, description: "Live music and performances to close out the night.", hasARCollectible: true, collectibleName: "Soundwave Snare", collectibleRarity: "Rare", collectibleIDs: ["c3"]),
        .init(pinType: .site, title: "Idea Lab Showcase", subtitle: "Day 2 • 1:00 PM – 2:30 PM • Idea Factory", latitude: 38.9907, longitude: -76.9375, description: "Explore projects and mini demos built for Henson Day.", hasARCollectible: false, collectibleName: nil, collectibleRarity: nil, collectibleIDs: [])
    ]
}
