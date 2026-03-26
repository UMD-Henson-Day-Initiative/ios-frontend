import Foundation
import CoreLocation
import MapKit

enum AppConstants {
    enum Debug {
        #if DEBUG
        static let isMapTeleportTestingEnabled = true
        #else
        static let isMapTeleportTestingEnabled = false
        #endif
    }

    enum Map {
        static let fallbackCampusCenter = CLLocationCoordinate2D(latitude: 38.9869, longitude: -76.9426)
        static let mapRegionSpan = MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
        static let locationFollowSpan = MKCoordinateSpan(latitudeDelta: 0.007, longitudeDelta: 0.007)
        static let primarySwapAnimationSeconds: TimeInterval = 0.2
    }

    enum AR {
        static let spawnRadiusMeters: CLLocationDistance = 30
        static let maxPlacements = 3
        static let walkAwayDistanceMeters: Float = 12

        static let teleportFallbackDelaySeconds: TimeInterval = 2.0
        static let teleportLaunchDelaySeconds: TimeInterval = 0.2
        static let captureDismissDelaySeconds: TimeInterval = 2.0
        static let collectRevealDelaySeconds: TimeInterval = 0.9
        static let collectDismissDelaySeconds: TimeInterval = 0.55
        static let collectibleAnimationCompletionDelaySeconds: TimeInterval = 0.48

        static let forcedSpawnDistanceMeters: Float = 0.9
        static let fallbackSphereRadius: Float = 0.12

        static let minScale: Float = 0.03
        static let maxScale: Float = 0.35
        static let fallbackUniformScale: Float = 0.12

        enum ModelSizing {
            static let defaultTargetMaxDimension: Float = 0.10
            static let smallTargetMaxDimension: Float = 0.07
            static let largeTargetMaxDimension: Float = 0.125

            static let targetDimensionByModelAsset: [String: Float] = [
                "toy_car": 0.07,
                "hummingbird_anim": 0.07,
                "robot": 0.125,
                "toy_biplane_realistic": 0.125,
                "slide": 0.10
            ]

            static let cameraPlacementToyDimension: Float = 0.14
            static let cameraPlacementLargeDimension: Float = 0.25
            static let cameraPlacementDefaultDimension: Float = 0.20
        }
    }

    enum SceneKitPortal {
        static let boxWidth: CGFloat = 0.2
        static let boxHeight: CGFloat = 1.0
        static let boxLength: CGFloat = 1.0
        static let doorLength: CGFloat = 0.3
    }
}
