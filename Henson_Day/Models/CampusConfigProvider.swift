import Foundation
import CoreLocation

protocol CampusConfigProviding {
    var campusCenter: CLLocationCoordinate2D { get }
}

struct LocalFallbackCampusConfigProvider: CampusConfigProviding {
    var campusCenter: CLLocationCoordinate2D {
        Database.campusCenterFallback
    }
}

enum CampusConfigProvider {
    static var active: CampusConfigProviding = LocalFallbackCampusConfigProvider()

    static var campusCenter: CLLocationCoordinate2D {
        active.campusCenter
    }
}
