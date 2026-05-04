//
//  LocationManager.swift
//  HensonDayInitiative
//
//  Created by Havish on 3/6/26.
//

import Foundation
import CoreLocation
import Combine
import MapKit
import AVFoundation

@MainActor
class LocationManager: NSObject, ObservableObject {
    private let manager = CLLocationManager()
    
    @Published var location: CLLocation?
    @Published var heading: CLHeading?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
        manager.headingFilter = 5
    }
    
    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }
    
    func startTracking() {
        manager.startUpdatingLocation()
        manager.startUpdatingHeading()
    }
    
    func stopTracking() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }
}

final class CameraPermissionManager: ObservableObject {
    @Published private(set) var authorizationStatus: AVAuthorizationStatus

    init() {
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorized
    }

    var isDeniedOrRestricted: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

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

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        Task { @MainActor in
            self.location = latest
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        Task { @MainActor in
            self.heading = newHeading
        }
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            if manager.authorizationStatus == .authorizedWhenInUse ||
               manager.authorizationStatus == .authorizedAlways {
                self.startTracking()
            }
        }
    }
}
