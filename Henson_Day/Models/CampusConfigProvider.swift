import Foundation
import CoreLocation
import MapKit

/// Provides dynamic campus configuration values (backend-ready abstraction).
protocol CampusConfigProviding {
    var campusCenter: CLLocationCoordinate2D { get }
    var mapSpan: (latDelta: Double, lonDelta: Double) { get }
    var spawnRadiusMeters: Int { get }
}

extension CampusConfigProviding {
    var mapSpan: (latDelta: Double, lonDelta: Double) {
        (AppConstants.Map.mapRegionSpan.latitudeDelta, AppConstants.Map.mapRegionSpan.longitudeDelta)
    }
    var spawnRadiusMeters: Int { Int(AppConstants.AR.spawnRadiusMeters) }
}

/// The default local provider that uses bundled fallback data.
struct LocalFallbackCampusConfigProvider: CampusConfigProviding {
    var campusCenter: CLLocationCoordinate2D {
        Database.campusCenterFallback
    }
}

/// Provider backed by a remote `CampusConfigDTO` from the content sync.
struct RemoteCampusConfigProvider: CampusConfigProviding {
    let dto: CampusConfigDTO

    var campusCenter: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: dto.centerLatitude, longitude: dto.centerLongitude)
    }

    var mapSpan: (latDelta: Double, lonDelta: Double) {
        (dto.mapSpanLatitudeDelta, dto.mapSpanLongitudeDelta)
    }

    var spawnRadiusMeters: Int {
        dto.defaultSpawnRadiusMeters
    }
}

/// Active provider can be replaced at startup when backend config is available.
enum CampusConfigProvider {
    static var active: CampusConfigProviding = LocalFallbackCampusConfigProvider()

    static var campusCenter: CLLocationCoordinate2D {
        active.campusCenter
    }

    /// Call after content sync to upgrade from fallback to remote config.
    static func applyRemoteConfig(_ dto: CampusConfigDTO) {
        active = RemoteCampusConfigProvider(dto: dto)
    }

    /// Reset to local fallback (e.g. on sign-out or sync failure).
    static func resetToFallback() {
        active = LocalFallbackCampusConfigProvider()
    }
}
