import SwiftUI
import MapKit
import CoreLocation
import Combine

struct MiniMapView: View {
    @ObservedObject var locationManager: LocationPermissionManager
    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        Group {
            if locationManager.isDeniedOrRestricted {
                LocationPermissionPlaceholder()
            } else {
                Map(position: $cameraPosition, interactionModes: [.all]) {
                    UserAnnotation()
                }
                .onAppear {
                    cameraPosition = .region(locationManager.region)
                    locationManager.requestWhenInUseAuthorizationIfNeeded()
                }
                .onReceive(locationManager.$region) { region in
                    cameraPosition = .region(region)
                }
            }
        }
    }
}

struct LocationPermissionPlaceholder: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.75)
            VStack(spacing: 8) {
                Image(systemName: "location.slash")
                    .font(.title3)
                    .foregroundStyle(.white)
                Text("Location access is disabled.")
                    .font(.footnote.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                Text("Enable Location permission to center the minimap.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(12)
        }
    }
}

final class LocationPermissionManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var region: MKCoordinateRegion
    @Published private(set) var currentCoordinate: CLLocationCoordinate2D?
    @Published var testingOverrideCoordinate: CLLocationCoordinate2D?
    @Published private(set) var lastTeleportDate: Date?

    private let manager = CLLocationManager()

    override init() {
        authorizationStatus = manager.authorizationStatus
        region = MKCoordinateRegion(
            center: CampusConfigProvider.campusCenter,
            span: AppConstants.Map.locationFollowSpan
        )
        super.init()

        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    var isDeniedOrRestricted: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    // Returns the mocked coordinate in testing mode, otherwise the live GPS coordinate.
    var effectiveCoordinate: CLLocationCoordinate2D? {
        testingOverrideCoordinate ?? currentCoordinate
    }

    // Teleports the app's effective position for testing AR proximity flows.
    func setTestingCoordinate(_ coordinate: CLLocationCoordinate2D?) {
        testingOverrideCoordinate = coordinate
        lastTeleportDate = Date()
        guard let coordinate else { return }
        region = MKCoordinateRegion(
            center: coordinate,
            span: AppConstants.Map.locationFollowSpan
        )
    }

    func requestWhenInUseAuthorizationIfNeeded() {
        let status = manager.authorizationStatus
        authorizationStatus = status

        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            manager.stopUpdatingLocation()
        @unknown default:
            manager.stopUpdatingLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        requestWhenInUseAuthorizationIfNeeded()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        Task { @MainActor in
            self.currentCoordinate = location.coordinate
            self.region = MKCoordinateRegion(
                center: location.coordinate,
                span: AppConstants.Map.locationFollowSpan
            )
        }
    }
}
