import Foundation
import CoreLocation

/// Shared app-wide constants for map defaults, the collect radius, and AR coin timing.
enum AppConstants {
    enum Map {
        static let campusBoundsMinLat = 38.981086
        static let campusBoundsMaxLat = 38.994498
        static let campusBoundsMinLon = -76.954429
        static let campusBoundsMaxLon = -76.934774
        static let cameraMinDistance: Double = 50
        static let cameraMaxDistance: Double = 3000
        static let defaultCameraDistance: Double = 350
        static let defaultCameraPitch: Double = 55
        static let followLossThreshold: Double = 0.0005
    }

    enum Collect {
        /// A user must be within this radius of an event's location to collect
        /// its coin. Matches the backend's own check (see
        /// backend/henson-backend/app/routes/events.py: COLLECT_RADIUS_METERS) —
        /// this is a UI convenience, the backend is the source of truth.
        static let radiusMeters: CLLocationDistance = 160.934  // 0.1 mile
    }

    enum AR {
        static let coinRadiusMeters: Float = 0.035
        static let coinThicknessMeters: Float = 0.006
        static let coinTapTargetRadiusMeters: Float = 0.09

        static let collectRevealDelaySeconds: TimeInterval = 0.9
        static let collectDismissDelaySeconds: TimeInterval = 1.2
        static let collectibleAnimationCompletionDelaySeconds: TimeInterval = 0.48
        static let pointsBurstAnimationSeconds: TimeInterval = 0.8
        static let collectTapSoundID: UInt32 = 1104
    }

    enum URLs {
        static let universityHome = "https://umd.edu/"
    }
}
