// ContentDTO.swift

import Foundation

/// Server bootstrap response returned by `GET /bootstrap`.
struct BootstrapDTO: Decodable {
    let campusConfig: CampusConfigDTO
    let currentSeason: SeasonDTO?
    let announcements: [AnnouncementDTO]
    let contentVersion: String
}

struct CampusConfigDTO: Decodable {
    let campusName: String
    let centerLatitude: Double
    let centerLongitude: Double
    let defaultSpawnRadiusMeters: Int
    let mapSpanLatitudeDelta: Double
    let mapSpanLongitudeDelta: Double
    let activeSeasonId: String?
}

struct SeasonDTO: Decodable {
    let id: String
    let slug: String
    let name: String
    let startsAt: Date
    let endsAt: Date
    let status: String
}

struct EventDTO: Decodable {
    let id: String
    let seasonId: String?
    let slug: String?
    let title: String
    let description: String
    let locationName: String
    let latitude: Double
    let longitude: Double
    let startsAt: Date
    let endsAt: Date
    let status: String
    let pinType: String
    let checkInPoints: Int?
    let heroImageUrl: String?
}

struct PinDTO: Decodable {
    let id: String
    let eventId: String?
    let title: String
    let subtitle: String?
    let description: String
    let latitude: Double
    let longitude: Double
    let pinType: String
    let status: String
    let isHidden: Bool?
    let hasArCollectible: Bool?
    let activationStartsAt: Date?
    let activationEndsAt: Date?
}

struct CollectibleDTO: Decodable {
    let id: String
    let slug: String?
    let name: String
    let rarity: String
    let modelFileName: String
    let imageUrl: String?
    let flavorText: String
    let points: Int
    let cp: Int
    let isActive: Bool?
    let types: [String]?
}

struct AnnouncementDTO: Decodable {
    let id: String
    let title: String
    let body: String
    let priority: String?
    let isActive: Bool?
}
