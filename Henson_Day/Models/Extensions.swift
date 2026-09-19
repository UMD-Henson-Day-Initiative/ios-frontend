import Foundation
import CoreLocation

/// Straight-line meters between two coordinates. Returns nil if either is nil.
func straightLineDistance(from a: CLLocationCoordinate2D?, to b: CLLocationCoordinate2D?) -> CLLocationDistance? {
    guard let a, let b else { return nil }
    return CLLocation(latitude: a.latitude, longitude: a.longitude)
        .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
}

extension Array where Element == Date {
    /// Today (start-of-day) if present in this list, otherwise the nearest
    /// upcoming date, otherwise the most recent past date. Used by both the
    /// Schedule and Map tabs so they default to the same day.
    func closestToToday(calendar: Calendar = .current) -> Date? {
        guard !isEmpty else { return nil }
        let sorted = self.sorted()
        let today = calendar.startOfDay(for: Date())
        if let match = sorted.first(where: { calendar.isDate($0, inSameDayAs: today) }) {
            return match
        }
        if let upcoming = sorted.first(where: { $0 > today }) {
            return upcoming
        }
        return sorted.last
    }
}
