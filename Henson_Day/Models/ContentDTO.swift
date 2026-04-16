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
    let collectibleName: String?
    let collectibleRarity: String?
    let collectibleIds: [String]?
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

// MARK: - DTO → local model converters

extension EventDTO {
    /// Convert to a `DatabaseEvent`, computing `dayNumber` relative to the season
    /// start date (or `AppConstants.Schedule.weekStart` as fallback).
    func toDatabaseEvent(seasonStart: Date? = nil) -> DatabaseEvent {
        let anchor = seasonStart ?? AppConstants.Schedule.weekStart
        let cal = Calendar.current
        let dayOffset = cal.dateComponents([.day], from: cal.startOfDay(for: anchor), to: cal.startOfDay(for: startsAt)).day ?? 0
        let dayNumber = max(1, dayOffset + 1)

        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        let timeRange = "\(fmt.string(from: startsAt)) – \(fmt.string(from: endsAt))"

        return DatabaseEvent(
            id: id,
            dayNumber: dayNumber,
            title: title,
            timeRange: timeRange,
            locationName: locationName,
            description: description,
            pinType: PinType(rawValue: pinType) ?? .event,
            collectibleName: nil
        )
    }
}

extension PinDTO {
    /// Convert to a `PinEntity` for SwiftData persistence.
    func toPinEntity() -> PinEntity {
        PinEntity(
            pinType: PinType(rawValue: pinType) ?? .site,
            remoteID: id,
            remoteEventID: eventId,
            title: title,
            subtitle: subtitle,
            latitude: latitude,
            longitude: longitude,
            pinDescription: description,
            status: status,
            hasARCollectible: hasArCollectible ?? false,
            activationStartsAt: activationStartsAt,
            activationEndsAt: activationEndsAt,
            collectibleName: collectibleName,
            collectibleRarity: collectibleRarity,
            collectibleIDs: collectibleIds ?? []
        )
    }
}

extension CollectibleDTO {
    /// Convert to a `DatabaseCollectible` for catalog display and AR flow.
    func toDatabaseCollectible() -> DatabaseCollectible {
        DatabaseCollectible(
            id: id,
            name: name,
            rarity: rarity,
            location: "",
            modelFileName: modelFileName,
            points: points,
            emoji: "",
            imageName: nil,
            flavorText: flavorText,
            types: types ?? [],
            cp: cp
        )
    }
}
