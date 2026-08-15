# Henson Day iOS App

Henson Day is a SwiftUI app for a campus event/scavenger-hunt at the University of Maryland. Users sign in with a UMD Google account, browse the schedule and map, collect an AR coin at each event's location for points, and check the leaderboard.

> `docs/real-functionality-roadmap.md` describes an earlier, larger backend rollout plan and is now superseded — the backend and this app were rebuilt directly against the simplified spec below rather than following that plan step by step. Keeping it around for historical context only.

## Architecture Overview

- App entry: `HensonDayApp.swift` — injects `AuthManager`/`AppSession`/`TabRouter`/`LocationManager`/`CameraPermissionManager`, and gates between `SignInScreen` and `RootTabView` based on Supabase auth state.
- Auth: `Models/AuthManager.swift` (Supabase Auth + native Google sign-in)
- Backend data: `Models/AppSession.swift` (state) + `Models/BackendAPI.swift` (REST client) + `Models/BackendModels.swift` (DTOs)
- Navigation: `Models/TabRouter.swift`
- Map + AR: `Views/MapScreen.swift`, `Views/MapView.swift`, `Views/PinDetailBottomSheet.swift`, `Views/ARCoinCollectView.swift`

There is no local persistence layer (no SwiftData) — every screen fetches from the Flask backend (see `../backend/henson-backend`) on appearance or pull-to-refresh.

## State Management

`AppSession` is the single source of truth for backend-fetched state:

- signed-in user's profile (name, email, points, events attended)
- event schedule
- leaderboard

`AuthManager` is the single source of truth for auth state (the current Supabase `Session`, or nil if signed out).

## Auth Flow

1. iOS signs in with Google via `GoogleSignIn-iOS`, getting an ID token.
2. `AuthManager` exchanges that token for a Supabase session via `signInWithIdToken`.
3. Every backend request attaches the session's access token as `Authorization: Bearer <token>`.
4. The backend enforces the `@umd.edu` / `@terpmail.umd.edu` domain restriction (Supabase itself doesn't restrict by domain) — a rejection here signs the user back out automatically (see `AppSession.wrongDomainDetected` and `HensonDayApp`'s `RootGateView`).
5. Sign-out calls Supabase's `signOut()` directly.

## Constants and Configuration

`Models/AppConstants.swift`:

- map region/camera defaults
- `Collect.radiusMeters` — 0.1 mile, matching the backend's own proximity check
- AR coin sizing/timing constants

`Models/AppEnvironment.swift` reads Supabase URL/anon key, the Google iOS client ID, and the Flask backend base URL from Info.plist — see `CLAUDE.md` for the exact keys and how to add the required Swift Package dependencies.

## Local Development

1. Open `Henson_Day.xcodeproj` in Xcode.
2. Add the two Swift Package dependencies (`supabase-swift`, `GoogleSignIn-iOS`) via File → Add Package Dependencies — see `CLAUDE.md`.
3. Add a URL Type in the target's Info tab for the Google iOS client's reversed client ID (needed for the sign-in callback).
4. Point `HENSON_API_BASE_URL` at your locally-running Flask backend (`http://localhost:5000` for Simulator, or your Mac's LAN IP for a physical device — required for testing AR, since ARKit doesn't run in Simulator).
5. Build and run.

## Validation Checklist

Use this checklist after major changes:

1. Sign-in flow: Google sign-in succeeds, non-UMD accounts get rejected and signed back out.
2. Schedule: every event shows with its correct day and time.
3. Map: day selector shows one pin per event for that day; tapping a pin shows details.
4. Pin detail: Navigate opens Apple Maps with the event as destination; Collect is disabled until within 0.1 miles.
5. AR collect flow: plane detection → coin placement → tap to collect → backend awards points → profile/leaderboard reflect the new total.
6. Leaderboard: top 10 renders correctly, sorted by points.
7. Profile: name/email/points/events attended are correct; sign out actually signs out.

## File Reference

### Henson_Day/ (App Root)

| File | Description |
|------|------|
| `HensonDayApp.swift` | App entry point; injects environment objects and gates sign-in vs. main app |

### Henson_Day/Models/

| File | Description |
|------|------|
| `AppConstants.swift` | Map defaults, the 0.1-mile collect radius, and AR coin sizing/timing constants |
| `AppEnvironment.swift` | Reads Supabase URL/key, Google client ID, and API base URL from Info.plist |
| `AppSession.swift` | Single source of truth for backend-fetched state: profile, events, leaderboard |
| `AuthManager.swift` | Supabase Auth + native Google sign-in wrapper |
| `BackendAPI.swift` | Thin REST client for the Flask backend, attaches Bearer token automatically |
| `BackendModels.swift` | Codable DTOs matching the backend's JSON: `Profile`, `EventItem`, `LeaderboardEntry`, `CollectResult`, `BackendError` |
| `DesignSystem.swift` | Central design token registry (colors, typography, radii, spacing, shadows) |
| `Extensions.swift` | `straightLineDistance` helper |
| `LocationManager.swift` | The single app-wide `CLLocationManager` wrapper + `CameraPermissionManager` |
| `TabRouter.swift` | Selected-tab state for the 5-tab root navigation |

### Henson_Day/Views/

| File | Description |
|------|------|
| `SignInScreen.swift` | Google-only sign-in gate, shows camera/location permission status |
| `RootTabView.swift` | 5-tab root navigation: Home, Schedule, Map, Leaderboard, Profile |
| `HomeScreen.swift` | Static feature explainer — what each tab does |
| `ScheduleScreen.swift` | Every event, grouped by day, with time/location/points |
| `MapScreen.swift` | Day selector + map of that day's event pins |
| `MapView.swift` | MapKit view with 3D camera, player marker, and event pins |
| `PinDetailBottomSheet.swift` | Pin tap detail sheet: Navigate (Apple Maps) + distance-gated Collect |
| `ARCoinCollectView.swift` | AR plane-detection + single procedural coin + backend collect call |
| `LeaderboardScreen.swift` | Top 10 players by points |
| `ProfileScreen.swift` | Name, email, points, events attended, sign out |
