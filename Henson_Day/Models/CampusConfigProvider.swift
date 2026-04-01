import Foundation
import CoreLocation

/// Provides dynamic campus configuration values (backend-ready abstraction).
protocol CampusConfigProviding {
    var campusCenter: CLLocationCoordinate2D { get }
}

/// The default local provider that uses bundled fallback data.
struct LocalFallbackCampusConfigProvider: CampusConfigProviding {
    var campusCenter: CLLocationCoordinate2D {
        Database.campusCenterFallback
    }
}

/// I dont see a backend anywhere so ->
/// Active provider can be replaced at startup when backend config is available.
enum CampusConfigProvider {
    static var active: CampusConfigProviding = LocalFallbackCampusConfigProvider()

    static var campusCenter: CLLocationCoordinate2D {
        active.campusCenter
    }
}
