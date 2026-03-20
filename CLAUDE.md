# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Henson Day is an iOS SwiftUI app for a campus-wide AR scavenger hunt at the University of Maryland. Users explore a map of campus, attend events, collect AR collectibles via the camera, earn points, and compete on a leaderboard.

## Build & Run

This is an Xcode project (no SPM Package.swift). Open `Henson_Day.xcodeproj` and build/run from Xcode.

```bash
# Build from command line
xcodebuild -project Henson_Day.xcodeproj -scheme Henson_Day -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run tests
xcodebuild -project Henson_Day.xcodeproj -scheme Henson_Day -destination 'platform=iOS Simulator,name=iPhone 16' test
```

Requires iOS device or simulator with camera and location capabilities. The app requests camera and location permissions on launch via `LaunchGateView`.

## Architecture

### App Entry & Navigation
- `HensonDayApp` → injects `ModelController` and `TabRouter` as environment objects
- `LaunchGateView` → permission gate (camera + location), then transitions to `RootTabView`
- `RootTabView` → 5-tab layout: Home, Schedule, Map, Collection, Profile
- `TabRouter` manages selected tab and cross-tab navigation (e.g. `focusedScheduleEventID` for deep-linking to schedule events)

### Data Layer
- **`ModelController`** — central data controller using **SwiftData** for persistence. Owns the `ModelContainer` and `ModelContext`. Seeds mock data on first launch from `Database.swift` static values. All published state flows from here.
- **`Database.swift`** — static seed data: players, pins (map locations), events, and collectible catalog. Campus center is hardcoded to UMD coordinates (38.9869, -76.9426).
- **SwiftData entities** (`PersistenceModels.swift`): `PlayerEntity`, `PinEntity`, `BadgeEntity`, `CollectedItemEntity`. Enums stored as raw strings (e.g. `pinTypeRaw`, `avatarTypeRaw`) with computed property wrappers.
- **`AppState.swift`** — older mock data holder (largely superseded by `ModelController`), still used by some views.

### Map & Location
- `LocationManager` — wraps `CLLocationManager` for real-time GPS + heading
- `RouteManager` — handles MapKit route/directions
- `MapView` / `MapScreen` — MapKit-based map with animated pins and 3D camera
- `PinDetailBottomSheet` — detail sheet when tapping a map pin
- `PinType` enum (in `MapPinDetail.swift`) — 6 types: site, event, collectible, battle, homebase, concert — each with distinct color and SF Symbol icon

### AR Features
- `ARCameraView`, `ARCanvasView`, `ARCollectibleExperienceView`, `ARCaptureScreen`, `HensonCameraRootView` — AR camera and collectible capture flow using RealityKit
- 3D models stored as `.usdz` files in `Henson_Day/3DModels/` — referenced by `modelFileName` in `Database.collectibleCatalog`

### Key Patterns
- All `@MainActor` for thread safety on `ObservableObject` classes
- Environment objects (`ModelController`, `TabRouter`) injected at app root and consumed via `@EnvironmentObject` throughout
- `CLLocationManagerDelegate` methods marked `nonisolated` with `Task { @MainActor in }` dispatch
