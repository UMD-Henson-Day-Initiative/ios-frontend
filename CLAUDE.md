# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Henson Day is an iOS SwiftUI app for a campus event/scavenger-hunt at the University of Maryland. Users sign in with a UMD Google account, browse the event schedule and map, walk to an event's location to collect its coin (points), and compete on a leaderboard. All data (profile, events, leaderboard, coin collection) lives on a Flask + Supabase backend (see `../backend/henson-backend`) — this app has no local persistence layer.

## Build & Run

This is an Xcode project (no SPM Package.swift for the app itself, though it depends on two Swift Package dependencies — see below). Open `Henson_Day.xcodeproj` and build/run from Xcode.

```bash
xcodebuild -project Henson_Day.xcodeproj -scheme Henson_Day -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build
```

Requires a device or simulator with camera and location capabilities. AR collection specifically requires a **real device** — ARKit does not run in the Simulator.

### Dependencies

Two Swift Package dependencies, added via Xcode's File → Add Package Dependencies (not hand-edited into `project.pbxproj`, since this project uses `PBXFileSystemSynchronizedRootGroup` for source files but package references still need Xcode's own bookkeeping):

- `supabase-swift` — Supabase Auth (Google sign-in) and session management.
- `GoogleSignIn-iOS` — native Google sign-in.

### Configuration

Backend config is read from Info.plist (`GENERATE_INFOPLIST_FILE = YES`, values set as `INFOPLIST_KEY_HENSON_*` build settings in `project.pbxproj`, see `Models/AppEnvironment.swift`):

- `HENSON_SUPABASE_URL` — the Supabase project URL.
- `HENSON_ANON_KEY` — Supabase's publishable (anon) key.
- `HENSON_GOOGLE_IOS_CLIENT_ID` — the iOS OAuth client ID, used to configure GoogleSignIn.
- `HENSON_API_BASE_URL` — the Flask backend's base URL (e.g. `http://localhost:5000` for Simulator; use your Mac's LAN IP when testing AR on a physical device, since `localhost` on-device means the device itself).

## Architecture

### App Entry & Navigation

- `HensonDayApp` → injects `AuthManager`, `AppSession`, `TabRouter`, `LocationManager`, `CameraPermissionManager` as environment objects; its `RootGateView` picks between a splash state, `SignInScreen`, and `RootTabView` based on `AuthManager.session`.
- `RootTabView` → 5-tab layout: Home, Schedule, Map, Leaderboard, Profile.
- `TabRouter` manages the selected tab.

### Auth

- `AuthManager` wraps Supabase Auth + native Google sign-in (`GoogleSignIn-iOS`). Sign-in is entirely client-side: Google issues an ID token, Supabase exchanges it for a session — the backend never sees a Google credential, it only verifies the resulting Supabase session JWT.
- UMD-domain restriction (`@umd.edu` / `@terpmail.umd.edu`) is enforced by the **backend**, not Supabase — `AppSession` detects a `wrongDomain` rejection from `GET /me` and `HensonDayApp` responds by signing the user back out.
- Sign-out is a real, direct call to Supabase's `signOut()` (no confirmation-only placeholder).

### Data Layer

- **`AppSession`** — single source of truth for backend-fetched state: `profile`, `events`, `leaderboard`. No local persistence (no SwiftData) — everything is fetched fresh from the backend and refreshed via pull-to-refresh or on tab appearance.
- **`BackendAPI`** — thin REST client for the Flask backend (`GET /me`, `GET /events`, `GET /events/<id>`, `POST /events/<id>/collect`, `GET /leaderboard`). Attaches the current Supabase session's access token as a Bearer header on every call.
- **`BackendModels.swift`** — `Profile`, `EventItem`, `LeaderboardEntry`, `CollectResult`, `BackendError` — Codable DTOs matching the backend's JSON exactly (see `../backend/henson-backend/README.md` for the exact contract).

### Map & Location

- **`LocationManager`** — the single app-wide `CLLocationManager` wrapper, injected once at the app root and shared by the sign-in permission check, the map, and the pin detail sheet's distance calculation.
- `MapView` / `MapScreen` — MapKit-based map with a day selector; shows one pin per event scheduled that day.
- `PinDetailBottomSheet` — shown when a pin is tapped: event info, a **Navigate** button (opens Apple Maps via `MKMapItem.openInMaps`), and a **Collect** button enabled only within `AppConstants.Collect.radiusMeters` (0.1 mile) of the event.

### AR Coin Collection

- `ARCoinCollectView` — full-screen AR flow (RealityKit `ARView` bridged via `ARPlacementView`): detects a horizontal plane, spawns a single procedurally-generated gold coin (no more per-collectible 3D assets or rarity system), and on tap submits `POST /events/<id>/collect` with the device's current coordinate. The backend re-validates proximity and awards points — the client never mints points itself.

### Key Patterns

- All `@MainActor` for thread safety on `ObservableObject` classes.
- Environment objects (`AuthManager`, `AppSession`, `TabRouter`, `LocationManager`, `CameraPermissionManager`) injected at the app root and consumed via `@EnvironmentObject` throughout.
- `CLLocationManagerDelegate` methods marked `nonisolated` with `Task { @MainActor in }` dispatch.
