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

## Future Backend Integration

To replace local campus fallback with backend config:

1. Add a new CampusConfigProviding implementation.
2. Fetch remote campus center and expose it via campusCenter.
3. Assign CampusConfigProvider.active at app launch.
4. Keep Database.campusCenterFallback for offline fallback mode.
