import Foundation
import Combine
import CoreLocation
import AVFoundation

/// Single app-wide location manager — injected once at the app root and shared
/// by the sign-in permission check, the map, and the pin detail sheet's
/// distance-to-collect calculation. (The app previously had three separate
/// CLLocationManager instances doing this independently; this replaces all of them.)
@MainActor
final class LocationManager: NSObject, ObservableObject {
    private let manager = CLLocationManager()

    @Published private(set) var location: CLLocation?
    @Published private(set) var heading: CLHeading?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus

    override init() {
        authorizationStatus = CLLocationManager().authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
        manager.headingFilter = 5
    }

    var coordinate: CLLocationCoordinate2D? { location?.coordinate }

    var isGranted: Bool {
        authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse
    }

    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    func requestWhenInUseAuthorizationIfNeeded() {
        let status = manager.authorizationStatus
        authorizationStatus = status
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            startTracking()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default:
            break
        }
    }

    func startTracking() {
        manager.startUpdatingLocation()
        manager.startUpdatingHeading()
    }

    func stopTracking() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }

    func distance(to coordinate: CLLocationCoordinate2D) -> CLLocationDistance? {
        guard let location else { return nil }
        return location.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        Task { @MainActor in self.location = latest }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        Task { @MainActor in self.heading = newHeading }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            if self.isGranted {
                self.startTracking()
            }
        }
    }
}

/// Camera permission, kept separate from location since it's a distinct
/// system permission gated independently in the sign-in flow and before AR.
@MainActor
final class CameraPermissionManager: ObservableObject {
    @Published private(set) var authorizationStatus: AVAuthorizationStatus

    init() {
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }

    var isAuthorized: Bool { authorizationStatus == .authorized }
    var isDeniedOrRestricted: Bool { authorizationStatus == .denied || authorizationStatus == .restricted }

    func requestIfNeeded() {
        let current = AVCaptureDevice.authorizationStatus(for: .video)
        authorizationStatus = current
        guard current == .notDetermined else { return }
        AVCaptureDevice.requestAccess(for: .video) { [weak self] _ in
            Task { @MainActor in
                self?.authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
            }
        }
    }
}
