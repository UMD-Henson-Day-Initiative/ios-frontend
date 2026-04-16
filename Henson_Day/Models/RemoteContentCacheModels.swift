import Foundation
import SwiftData

@Model
final class CachedContentMetadataEntity {
    @Attribute(.unique) var key: String
    var contentVersion: String
    var lastSuccessfulSyncAt: Date
    var lastSuccessfulFullSyncAt: Date

    init(
        key: String = "current",
        contentVersion: String = "1",
        lastSuccessfulSyncAt: Date = .distantPast,
        lastSuccessfulFullSyncAt: Date = .distantPast
    ) {
        self.key = key
        self.contentVersion = contentVersion
        self.lastSuccessfulSyncAt = lastSuccessfulSyncAt
        self.lastSuccessfulFullSyncAt = lastSuccessfulFullSyncAt
    }
}

@Model
final class CachedCampusConfigEntity {
    @Attribute(.unique) var key: String
    var campusName: String
    var centerLatitude: Double
    var centerLongitude: Double
    var defaultSpawnRadiusMeters: Int
    var mapSpanLatitudeDelta: Double
    var mapSpanLongitudeDelta: Double
    var activeSeasonId: String?

    init(
        key: String = "current",
        campusName: String = "",
        centerLatitude: Double = 0,
        centerLongitude: Double = 0,
        defaultSpawnRadiusMeters: Int = 0,
        mapSpanLatitudeDelta: Double = 0,
        mapSpanLongitudeDelta: Double = 0,
        activeSeasonId: String? = nil
    ) {
        self.key = key
        self.campusName = campusName
        self.centerLatitude = centerLatitude
        self.centerLongitude = centerLongitude
        self.defaultSpawnRadiusMeters = defaultSpawnRadiusMeters
        self.mapSpanLatitudeDelta = mapSpanLatitudeDelta
        self.mapSpanLongitudeDelta = mapSpanLongitudeDelta
        self.activeSeasonId = activeSeasonId
    }

    convenience init(dto: CampusConfigDTO) {
        self.init()
        apply(dto)
    }

    func apply(_ dto: CampusConfigDTO) {
        campusName = dto.campusName
        centerLatitude = dto.centerLatitude
        centerLongitude = dto.centerLongitude
        defaultSpawnRadiusMeters = dto.defaultSpawnRadiusMeters
        mapSpanLatitudeDelta = dto.mapSpanLatitudeDelta
        mapSpanLongitudeDelta = dto.mapSpanLongitudeDelta
        activeSeasonId = dto.activeSeasonId
    }
}

@Model
final class CachedSeasonEntity {
    @Attribute(.unique) var id: String
    var slug: String
    var name: String
    var startsAt: Date
    var endsAt: Date
    var status: String

    init(id: String, slug: String, name: String, startsAt: Date, endsAt: Date, status: String) {
        self.id = id
        self.slug = slug
        self.name = name
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.status = status
    }

    convenience init(dto: SeasonDTO) {
        self.init(id: dto.id, slug: dto.slug, name: dto.name, startsAt: dto.startsAt, endsAt: dto.endsAt, status: dto.status)
    }

    func apply(_ dto: SeasonDTO) {
        slug = dto.slug
        name = dto.name
        startsAt = dto.startsAt
        endsAt = dto.endsAt
        status = dto.status
    }
}

@Model
final class CachedEventEntity {
    @Attribute(.unique) var id: String
    var seasonId: String?
    var slug: String?
    var title: String
    var eventDescription: String
    var locationName: String
    var latitude: Double
    var longitude: Double
    var startsAt: Date
    var endsAt: Date
    var status: String
    var pinType: String
    var checkInPoints: Int?
    var heroImageUrl: String?

    init(
        id: String,
        seasonId: String?,
        slug: String?,
        title: String,
        eventDescription: String,
        locationName: String,
        latitude: Double,
        longitude: Double,
        startsAt: Date,
        endsAt: Date,
        status: String,
        pinType: String,
        checkInPoints: Int?,
        heroImageUrl: String?
    ) {
        self.id = id
        self.seasonId = seasonId
        self.slug = slug
        self.title = title
        self.eventDescription = eventDescription
        self.locationName = locationName
        self.latitude = latitude
        self.longitude = longitude
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.status = status
        self.pinType = pinType
        self.checkInPoints = checkInPoints
        self.heroImageUrl = heroImageUrl
    }

    convenience init(dto: EventDTO) {
        self.init(
            id: dto.id,
            seasonId: dto.seasonId,
            slug: dto.slug,
            title: dto.title,
            eventDescription: dto.description,
            locationName: dto.locationName,
            latitude: dto.latitude,
            longitude: dto.longitude,
            startsAt: dto.startsAt,
            endsAt: dto.endsAt,
            status: dto.status,
            pinType: dto.pinType,
            checkInPoints: dto.checkInPoints,
            heroImageUrl: dto.heroImageUrl
        )
    }

    func apply(_ dto: EventDTO) {
        seasonId = dto.seasonId
        slug = dto.slug
        title = dto.title
        eventDescription = dto.description
        locationName = dto.locationName
        latitude = dto.latitude
        longitude = dto.longitude
        startsAt = dto.startsAt
        endsAt = dto.endsAt
        status = dto.status
        pinType = dto.pinType
        checkInPoints = dto.checkInPoints
        heroImageUrl = dto.heroImageUrl
    }
}

@Model
final class CachedPinEntity {
    @Attribute(.unique) var id: String
    var eventId: String?
    var title: String
    var subtitle: String?
    var pinDescription: String
    var latitude: Double
    var longitude: Double
    var pinType: String
    var status: String
    var isHidden: Bool
    var hasArCollectible: Bool
    var activationStartsAt: Date?
    var activationEndsAt: Date?

    init(
        id: String,
        eventId: String?,
        title: String,
        subtitle: String?,
        pinDescription: String,
        latitude: Double,
        longitude: Double,
        pinType: String,
        status: String,
        isHidden: Bool,
        hasArCollectible: Bool,
        activationStartsAt: Date?,
        activationEndsAt: Date?
    ) {
        self.id = id
        self.eventId = eventId
        self.title = title
        self.subtitle = subtitle
        self.pinDescription = pinDescription
        self.latitude = latitude
        self.longitude = longitude
        self.pinType = pinType
        self.status = status
        self.isHidden = isHidden
        self.hasArCollectible = hasArCollectible
        self.activationStartsAt = activationStartsAt
        self.activationEndsAt = activationEndsAt
    }

    convenience init(dto: PinDTO) {
        self.init(
            id: dto.id,
            eventId: dto.eventId,
            title: dto.title,
            subtitle: dto.subtitle,
            pinDescription: dto.description,
            latitude: dto.latitude,
            longitude: dto.longitude,
            pinType: dto.pinType,
            status: dto.status,
            isHidden: dto.isHidden ?? false,
            hasArCollectible: dto.hasArCollectible ?? false,
            activationStartsAt: dto.activationStartsAt,
            activationEndsAt: dto.activationEndsAt
        )
    }

    func apply(_ dto: PinDTO) {
        eventId = dto.eventId
        title = dto.title
        subtitle = dto.subtitle
        pinDescription = dto.description
        latitude = dto.latitude
        longitude = dto.longitude
        pinType = dto.pinType
        status = dto.status
        isHidden = dto.isHidden ?? false
        hasArCollectible = dto.hasArCollectible ?? false
        activationStartsAt = dto.activationStartsAt
        activationEndsAt = dto.activationEndsAt
    }
}

@Model
final class CachedCollectibleEntity {
    @Attribute(.unique) var id: String
    var slug: String?
    var name: String
    var rarity: String
    var modelFileName: String
    var imageUrl: String?
    var flavorText: String
    var points: Int
    var cp: Int
    var isActive: Bool
    var typesRaw: String

    init(
        id: String,
        slug: String?,
        name: String,
        rarity: String,
        modelFileName: String,
        imageUrl: String?,
        flavorText: String,
        points: Int,
        cp: Int,
        isActive: Bool,
        typesRaw: String
    ) {
        self.id = id
        self.slug = slug
        self.name = name
        self.rarity = rarity
        self.modelFileName = modelFileName
        self.imageUrl = imageUrl
        self.flavorText = flavorText
        self.points = points
        self.cp = cp
        self.isActive = isActive
        self.typesRaw = typesRaw
    }

    convenience init(dto: CollectibleDTO) {
        self.init(
            id: dto.id,
            slug: dto.slug,
            name: dto.name,
            rarity: dto.rarity,
            modelFileName: dto.modelFileName,
            imageUrl: dto.imageUrl,
            flavorText: dto.flavorText,
            points: dto.points,
            cp: dto.cp,
            isActive: dto.isActive ?? true,
            typesRaw: (dto.types ?? []).joined(separator: ",")
        )
    }

    func apply(_ dto: CollectibleDTO) {
        slug = dto.slug
        name = dto.name
        rarity = dto.rarity
        modelFileName = dto.modelFileName
        imageUrl = dto.imageUrl
        flavorText = dto.flavorText
        points = dto.points
        cp = dto.cp
        isActive = dto.isActive ?? true
        typesRaw = (dto.types ?? []).joined(separator: ",")
    }
}

@Model
final class CachedAnnouncementEntity {
    @Attribute(.unique) var id: String
    var title: String
    var body: String
    var priority: String?
    var isActive: Bool

    init(id: String, title: String, body: String, priority: String?, isActive: Bool) {
        self.id = id
        self.title = title
        self.body = body
        self.priority = priority
        self.isActive = isActive
    }

    convenience init(dto: AnnouncementDTO) {
        self.init(id: dto.id, title: dto.title, body: dto.body, priority: dto.priority, isActive: dto.isActive ?? true)
    }

    func apply(_ dto: AnnouncementDTO) {
        title = dto.title
        body = dto.body
        priority = dto.priority
        isActive = dto.isActive ?? true
    }
}

extension CampusConfigDTO {
    init(_ entity: CachedCampusConfigEntity) {
        self.init(
            campusName: entity.campusName,
            centerLatitude: entity.centerLatitude,
            centerLongitude: entity.centerLongitude,
            defaultSpawnRadiusMeters: entity.defaultSpawnRadiusMeters,
            mapSpanLatitudeDelta: entity.mapSpanLatitudeDelta,
            mapSpanLongitudeDelta: entity.mapSpanLongitudeDelta,
            activeSeasonId: entity.activeSeasonId
        )
    }
}

extension SeasonDTO {
    init(_ entity: CachedSeasonEntity) {
        self.init(
            id: entity.id,
            slug: entity.slug,
            name: entity.name,
            startsAt: entity.startsAt,
            endsAt: entity.endsAt,
            status: entity.status
        )
    }
}

extension EventDTO {
    init(_ entity: CachedEventEntity) {
        self.init(
            id: entity.id,
            seasonId: entity.seasonId,
            slug: entity.slug,
            title: entity.title,
            description: entity.eventDescription,
            locationName: entity.locationName,
            latitude: entity.latitude,
            longitude: entity.longitude,
            startsAt: entity.startsAt,
            endsAt: entity.endsAt,
            status: entity.status,
            pinType: entity.pinType,
            checkInPoints: entity.checkInPoints,
            heroImageUrl: entity.heroImageUrl
        )
    }
}

extension PinDTO {
    init(_ entity: CachedPinEntity) {
        self.init(
            id: entity.id,
            eventId: entity.eventId,
            title: entity.title,
            subtitle: entity.subtitle,
            description: entity.pinDescription,
            latitude: entity.latitude,
            longitude: entity.longitude,
            pinType: entity.pinType,
            status: entity.status,
            isHidden: entity.isHidden,
            hasArCollectible: entity.hasArCollectible,
            activationStartsAt: entity.activationStartsAt,
            activationEndsAt: entity.activationEndsAt
        )
    }
}

extension CollectibleDTO {
    init(_ entity: CachedCollectibleEntity) {
        let types = entity.typesRaw.isEmpty ? [] : entity.typesRaw.split(separator: ",").map(String.init)
        self.init(
            id: entity.id,
            slug: entity.slug,
            name: entity.name,
            rarity: entity.rarity,
            modelFileName: entity.modelFileName,
            imageUrl: entity.imageUrl,
            flavorText: entity.flavorText,
            points: entity.points,
            cp: entity.cp,
            isActive: entity.isActive,
            types: types
        )
    }
}

extension AnnouncementDTO {
    init(_ entity: CachedAnnouncementEntity) {
        self.init(
            id: entity.id,
            title: entity.title,
            body: entity.body,
            priority: entity.priority,
            isActive: entity.isActive
        )
    }
}