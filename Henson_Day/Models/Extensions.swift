import Foundation
import CoreLocation

/// Straight-line meters between two coordinates. Returns nil if either is nil.
func straightLineDistance(from a: CLLocationCoordinate2D?, to b: CLLocationCoordinate2D?) -> CLLocationDistance? {
    guard let a, let b else { return nil }
    return CLLocation(latitude: a.latitude, longitude: a.longitude)
        .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
}
