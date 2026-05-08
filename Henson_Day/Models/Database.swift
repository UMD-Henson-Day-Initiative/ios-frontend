import Foundation
import CoreLocation

/// Static seed data for the Henson Day app.
///
/// `Database` is the single source of truth for offline / first-launch content.
/// `ModelController` reads these values during initial seeding to populate SwiftData
/// entities (`PlayerEntity`, `PinEntity`, etc.). Nothing here is persisted directly —
/// treat it as a compile-time fixture file analogous to a JSON bundle asset.
///
/// The intermediate "Seed" / value types (`DatabasePlayerSeed`, `DatabasePinSeed`,
/// `DatabaseEvent`, `DatabaseCollectible`) are plain structs used only for seeding
/// and in-memory catalog lookups; they are not SwiftData models.

/// Plain-struct representation of a player used during first-launch seeding.
/// Converted to `PlayerEntity` by `ModelController.seedIfNeeded()`.
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

    var eventTypeName: String {
        switch pinType {
        case .collectible: return "Hunt"
        case .event:       return "Rally"
        case .battle:      return "Battle"
        case .concert:     return "Concert"
        case .site:        return "Showcase"
        case .homebase:    return "Check-In"
        }
    }

    var derivedRarity: String {
        switch pinType {
        case .concert, .homebase:
            return "Legendary"
        case .event, .battle:
            return "Rare"
        default:
            return "Common"
        }
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
    let emoji: String
    // Filename (without extension) in Henson_Day/Images/ for the AVIF photo.
    let imageName: String?
    let flavorText: String
    let types: [String]
    let cp: Int
}

enum Database {
    // Local fallback only. CampusConfigProvider can be swapped for backend-driven config.
    static let campusCenterFallback = AppConstants.Map.fallbackCampusCenter

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
        .init(id: "event-3", dayNumber: 2, title: "Terp Team Battle", timeRange: "3:00 PM – 4:00 PM", locationName: "Stamp Student Union", description: "Compete in a friendly AR battle challenge for bonus points.", pinType: .battle, collectibleName: "Battle Buddy"),
        .init(id: "event-4", dayNumber: 2, title: "Idea Lab Showcase", timeRange: "1:00 PM – 2:30 PM", locationName: "Idea Factory", description: "Explore student projects and collect showcase-only items.", pinType: .site, collectibleName: "Lab Spark"),
        .init(id: "event-5", dayNumber: 3, title: "Evening Concert", timeRange: "7:30 PM – 9:00 PM", locationName: "Chapel Field", description: "Live music with a limited-time AR collectible drop.", pinType: .concert, collectibleName: "Soundwave Snare"),
        .init(id: "event-6", dayNumber: 4, title: "Henson Homebase Daily Check-In", timeRange: "10:00 AM – 8:00 PM", locationName: "Hornbake Plaza", description: "Stop by Homebase to claim perks and hints for nearby collectibles.", pinType: .homebase, collectibleName: "Homebase Hero"),
        .init(id: "event-7", dayNumber: 5, title: "Quantum Courtyard Pop-Up", timeRange: "12:00 PM – 1:30 PM", locationName: "IRB Courtyard", description: "Short-form AR activity with bonus points for fast captures.", pinType: .event, collectibleName: "Quantum Smth"),
        .init(id: "event-8", dayNumber: 6, title: "Terrapin Twilight Run", timeRange: "6:30 PM – 8:00 PM", locationName: "Lot 1 Loop", description: "A campus run with geo-tagged AR checkpoints.", pinType: .site, collectibleName: "Night Runner"),
        .init(id: "event-9", dayNumber: 7, title: "Finale Badge Sprint", timeRange: "4:00 PM – 6:00 PM", locationName: "McKeldin Steps", description: "Last chance to complete collections and earn final badges.", pinType: .battle, collectibleName: "Finale Flare")
    ]

    static let collectibleCatalog: [DatabaseCollectible] = [
        .init(id: "c1", name: "Stadium Stomper", rarity: "Rare",      location: "Maryland Stadium",    modelFileName: "robot",                 points: 50,  emoji: "🏟️", imageName: "premium_photo-1764702327295-2ff77a60954f", flavorText: "A legendary stomper who thunders across the stadium field, rattling the bleachers with every step.",      types: ["Ground", "Fire"],    cp: 780),
        .init(id: "c2", name: "Mall Muppet",     rarity: "Common",   location: "McKeldin Mall",       modelFileName: "toy_car",               points: 40,  emoji: "🐢", imageName: "photo-1775584049939-2b284e207375",              flavorText: "A cheerful wanderer who calls the mall home, collecting dropped coins and leftover fries.",             types: ["Nature", "Water"],   cp: 540),
        .init(id: "c3", name: "Soundwave Snare", rarity: "Rare",     location: "Chapel Field",        modelFileName: "hummingbird_anim",      points: 55,  emoji: "🎵", imageName: "photo-1674424832822-1cb49a329fb9",              flavorText: "Born from a standing ovation, this creature vibrates at precisely 440 Hz at all times.",              types: ["Electric", "Sound"],  cp: 820),
        .init(id: "c4", name: "Quantum Smth",    rarity: "Legendary", location: "IRB Courtyard",       modelFileName: "toy_biplane_realistic", points: 75,  emoji: "⚡", imageName: "premium_photo-1720694751690-ab68c805bf36",      flavorText: "Exists in two places at once. Science cannot explain it. Facilities management finds this deeply inconvenient.", types: ["Psychic", "Tech"], cp: 1520),
        .init(id: "c5", name: "Finale Flare",    rarity: "Legendary", location: "McKeldin Steps",      modelFileName: "slide",                 points: 100, emoji: "⭐", imageName: "premium_photo-1774881398780-9c98f9110cfb",      flavorText: "Only appears on the final day. Those who find it are said to carry some of its glow for years.",       types: ["Mystic", "Fire"],    cp: 1920),
        .init(id: "c6", name: "Battle Buddy",    rarity: "Rare",      location: "Stamp Student Union", modelFileName: "robot",                 points: 50,  emoji: "🤺", imageName: "premium_photo-1775450651387-2a2085698dad",      flavorText: "Forged in the heat of the Terp Team Battle, it respects a worthy opponent above all else.",           types: ["Fighting", "Steel"], cp: 760),
        .init(id: "c7", name: "Lab Spark",       rarity: "Common",   location: "Idea Factory",        modelFileName: "toy_car",               points: 30,  emoji: "🔬", imageName: "premium_photo-1673281336580-92e2bc649008",      flavorText: "Hatched from an unattended Petri dish. Highly curious. Do not leave near open notebooks.",              types: ["Electric", "Smart"], cp: 420),
        .init(id: "c8", name: "Homebase Hero",   rarity: "Common",   location: "Hornbake Plaza",      modelFileName: "hummingbird_anim",      points: 25,  emoji: "🏠", imageName: nil,                                             flavorText: "The unsung guardian of Homebase. Every day, exactly 10:00 AM. Never late, never early.",               types: ["Normal"],            cp: 310),
        .init(id: "c9", name: "Night Runner",    rarity: "Rare",     location: "Lot 1 Loop",          modelFileName: "toy_biplane_realistic", points: 45,  emoji: "🌙", imageName: nil,                                             flavorText: "Spotted only after dark, circling the loop at a pace no runner can match.",                             types: ["Shadow", "Speed"],   cp: 690),
        .init(id: "c10", name: "Jim Henson Puppet", rarity: "Legendary", location: "Stamp Student Union", modelFileName: "jimhensonpuppet",       points: 150, emoji: "🎭", imageName: nil,                                             flavorText: "A tribute to the visionary behind the Muppets. Stops by campus once a year — usually when no one's watching.", types: ["Mystic", "Normal"], cp: 2100)
    ]

    static let pins: [DatabasePinSeed] = [
        .init(pinType: .event, title: "Stadium Spirit Rally", subtitle: "Day 1 • 5:00 PM – 7:00 PM • Maryland Stadium", latitude: 38.9903, longitude: -76.9457, description: "Show your Terp pride at the opening rally, featuring music and performances.", hasARCollectible: true, collectibleName: "Stadium Stomper", collectibleRarity: "Rare", collectibleIDs: ["c1"]),
        .init(pinType: .collectible, title: "McKeldin Time Capsule", subtitle: "Day 1 • 2:30 PM – 4:00 PM • McKeldin Mall", latitude: 38.9857, longitude: -76.9456, description: "A hidden AR collectible near the center of the mall.", hasARCollectible: true, collectibleName: "Mall Muppet", collectibleRarity: "Common", collectibleIDs: ["c2"]),
        .init(pinType: .battle, title: "Terp Team Battle", subtitle: "Day 2 • 3:00 PM – 4:00 PM • Stamp Student Union", latitude: 38.9881, longitude: -76.9447, description: "Start a friendly AR faceoff and earn bonus points.", hasARCollectible: false, collectibleName: nil, collectibleRarity: nil, collectibleIDs: []),
        .init(pinType: .homebase, title: "Henson Homebase", subtitle: "Day 4 • 10:00 AM – 8:00 PM • Hornbake Plaza", latitude: 38.9889, longitude: -76.9418, description: "Check in to collect daily perks and hints.", hasARCollectible: false, collectibleName: nil, collectibleRarity: nil, collectibleIDs: []),
        .init(pinType: .concert, title: "Evening Concert", subtitle: "Day 3 • 7:30 PM – 9:00 PM • Chapel Field", latitude: 38.9878, longitude: -76.9392, description: "Live music and performances to close out the night.", hasARCollectible: true, collectibleName: "Soundwave Snare", collectibleRarity: "Rare", collectibleIDs: ["c3"]),
        .init(pinType: .site, title: "Idea Lab Showcase", subtitle: "Day 2 • 1:00 PM – 2:30 PM • Idea Factory", latitude: 38.9907, longitude: -76.9375, description: "Explore projects and mini demos built for Henson Day.", hasARCollectible: false, collectibleName: nil, collectibleRarity: nil, collectibleIDs: []),
        .init(pinType: .collectible, title: "Jim Henson Statue", subtitle: "All Week • Outside Stamp Student Union", latitude: 38.98793, longitude: -76.94455, description: "The Jim Henson + Kermit statue. Approach to find a special AR collectible — a placeholder sentence for demo day.", hasARCollectible: true, collectibleName: "Jim Henson Puppet", collectibleRarity: "Legendary", collectibleIDs: ["c10"])
    ]
}
