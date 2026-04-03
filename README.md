# Henson Day iOS App

Henson Day is a SwiftUI + SwiftData + RealityKit app for a campus AR scavenger hunt. Users browse map pins, open event details, capture AR collectibles, and track leaderboard/collection progress.

## Architecture Overview

- App entry: HensonDayApp.swift
- App startup gate: Views/LaunchGateView.swift
- Single app state source: Models/ModelController.swift
- Navigation routing: Models/TabRouter.swift
- Persistence models: Models/PersistenceModels.swift
- Seed/fallback data: Models/Database.swift
- AR map flow: Views/MapScreen.swift, Views/ARCameraView.swift, Views/ARCollectibleExperienceView.swift

## State Management

ModelController is the single source of truth for:

- current user
- map pins
- leaderboard
- schedule events
- collectible catalog
- startup/runtime error state

The app no longer uses AppState.swift.

## Error Handling Strategy

### Startup failures

ModelController exposes startupErrorMessage when SwiftData cannot initialize or seed. LaunchGateView blocks entry and shows a Retry button.

### Runtime failures

ModelController publishes userFacingError for non-startup failures (fetch/save/refresh issues). RootTabView renders this as a user-visible alert.

## Constants and Configuration

Centralized constants live in Models/AppConstants.swift:

- map region defaults
- AR timing values
- AR placement sizing and limits
- SceneKit portal defaults

Campus config abstraction lives in Models/CampusConfigProvider.swift:

- CampusConfigProvider.active can be swapped for a backend implementation later
- Database.campusCenterFallback remains the local fallback value

## Threading Model

- ModelController is @MainActor because it owns UI-observed published state
- Delay-based UI flows use Task.sleep with cancellable Task handles
- Delegate callbacks hop to MainActor before mutating observable state

## Local Development

1. Open Henson_Day.xcodeproj in Xcode.
2. Select a simulator/device with camera/location capability as needed.
3. Build and run.

## Validation Checklist

Use this checklist after major changes:

1. Launch and verify startup gate behavior.
2. Permissions flow:
   - camera permission prompt/denied behavior
   - location permission prompt/denied behavior
3. Map to AR flow:
   - open pin details
   - open event details
   - launch AR collectible experience
4. Capture flow:
   - collectible capture increments points/collection
   - collection tab reflects new item
5. Leaderboard flow:
   - leaderboard renders and sorts correctly
6. Error surfaces:
   - startup failure shows retry UI
   - runtime failures show alert banner/dialog

## File Reference

### Henson_Day/ (App Root)
| File | Description |
|------|-------------|
| `HensonDayApp.swift` | App entry point; creates and injects all environment objects into the view hierarchy |

### Henson_Day/Models/
| File | Description |
|------|-------------|
| `AppConstants.swift` | Centralized configuration constants for map, AR, routing, URLs, and debug flags |
| `BadgeModel.swift` | Badge data model for the achievement/badge system |
| `CampusConfigProvider.swift` | Protocol abstraction for campus coordinates; swap for backend implementation when ready |
| `CollectibleModel.swift` | Data model for individual collectible items |
| `Database.swift` | Static seed data (pins, events, collectibles, players) used for first-launch SwiftData seeding |
| `EventModel.swift` | Data model for schedule events |
| `Extensions.swift` | SceneKit and RealityKit utility extensions |
| `FilterChip.swift` | Reusable filter chip UI model for schedule and collection filtering |
| `LeaderboardModel.swift` | Data model for leaderboard entries |
| `LocationManager.swift` | CLLocationManager wrapper publishing live GPS location and heading |
| `MapPinDetail.swift` | View-model bridging PinEntity to PinDetailBottomSheet; also defines PinType enum with colors and icons |
| `ModelController.swift` | Central data controller using SwiftData; owns all published app state and persistence |
| `PersistenceModels.swift` | SwiftData @Model entities: PlayerEntity, PinEntity, BadgeEntity, CollectedItemEntity |
| `ProximityMonitor.swift` | Monitors user's distance to collectible pins and publishes proximity alerts |
| `RouteManager.swift` | Calculates and tracks in-app walking directions using MapKit |
| `TabRouter.swift` | Cross-tab navigation state; supports deep-linking from map pins to schedule events |
| `UserDatabase.swift` | Convenience helpers that derive view-ready snapshots from ModelController |
| `UserModel.swift` | Plain user data model used before SwiftData seeding |

### Henson_Day/Views/
| File | Description |
|------|-------------|
| `ARCameraView.swift` | RealityKit AR camera view with tap-to-place collectibles and world anchor persistence |
| `ARCanvasView.swift` | AR canvas for free-form placement experiments |
| `ARCaptureScreen.swift` | UI screen shown during AR collectible capture sequence |
| `ARCollectibleExperienceView.swift` | Full-screen AR state machine: approach → surface detect → place → tap → collect |
| `ARMapContainerView.swift` | Container toggling between full-screen AR and map with overlay swap |
| `CollectionScreen.swift` | Displays collected items and full collectible catalog with collected/uncollected status |
| `EventDetailScreen.swift` | Detail view for a single schedule event with map navigation and collection links |
| `HomeScreen.swift` | Home tab with summary stats, recent activity, and quick navigation |
| `LaunchGateView.swift` | Startup permission gate for camera and location; blocks entry until both are granted |
| `LeaderboardScreen.swift` | Campus-wide leaderboard sorted by total points |
| `MapScreen.swift` | Primary map + camera split view; handles pin selection, AR launch, and teleport testing |
| `MapView.swift` | MapKit map with 3D camera, animated pins, compass follow toggle, and campus bounds |
| `MiniMapView.swift` | Compact map view used as the swap overlay in the AR/map split view |
| `MinimalLeaderboardSheet.swift` | Compact leaderboard sheet presented from the map screen |
| `MyCollectionSheet.swift` | Quick-view collection sheet presented from the map screen |
| `PinDetailBottomSheet.swift` | Bottom sheet shown when a map pin is tapped; supports drag-to-dismiss and contextual actions |
| `ProfileScreen.swift` | User profile with avatar customization, stats, and badge display |
| `ProximityAlertBanner.swift` | Animated banner shown when the user is near a collectible pin |
| `RootTabView.swift` | 5-tab root navigation: Home, Schedule, Map, Collection, Profile |
| `ScheduleScreen.swift` | Day-filtered event schedule with deep-link support from map pins |

## Future Backend Integration

To replace local campus fallback with backend config:

1. Add a new CampusConfigProviding implementation.
2. Fetch remote campus center and expose it via campusCenter.
3. Assign CampusConfigProvider.active at app launch.
4. Keep Database.campusCenterFallback for offline fallback mode.
