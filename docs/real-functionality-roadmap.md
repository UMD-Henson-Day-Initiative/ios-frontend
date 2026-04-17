# HensonDay Real Functionality Roadmap

## Goal

Move the app from a polished local-first prototype into a production-capable campus event app with:

- live event and map content
- authenticated users
- server-backed player progress
- server-validated collectible capture and check-in flows
- operational tooling for running an actual Henson Day week

This plan is intentionally aligned to the current codebase, especially these existing seams:

- `Henson_Day/Models/ModelController.swift`
- `Henson_Day/Views/ContentService.swift`
- `Henson_Day/Models/CampusConfigProvider.swift`
- `Henson_Day/Views/MapScreen.swift`
- `Henson_Day/Views/ARCollectibleExperienceView.swift`
- `Henson_Day/Views/ProfileScreen.swift`
- `Henson_Day/Views/EventDetailScreen.swift`

## Working Assumptions

- Backend stack: managed Postgres plus auth and storage, using Supabase as the default recommendation.
- App remains local-first for reads where possible, but write-side game rules become server authoritative.
- SwiftData remains useful as an offline cache and local UI store.
- AR model files can stay bundled initially. Remote model delivery can wait until gameplay rules are stable.
- The main launch milestone is a pilot event, not App Store scale on day one.

## Build Order

Implement in this order:

1. Live content sync
2. Real auth and player sync
3. Server-backed check-ins and leaderboard
4. Server-validated collectible capture
5. Admin and operations tooling

This order gives the fastest path from demo app to usable event product.

## 20 Week Checklist

### Month 1, Platform Foundation

#### Week 1, Architecture lock and data contracts

- Pick the backend stack and freeze it for the first release.
- Define environments: local, staging, production.
- Write version 1 entity contracts for users, events, pins, collectibles, captures, badges, leaderboard entries.
- Decide what is server authoritative.
- Server authoritative: points, captures, check-ins, leaderboard rank, eligibility.
- Client authoritative: UI animation state, transient AR state, cached content display.
- Add a lightweight architecture note covering cache strategy, offline behavior, and sync ownership.
- Exit criteria: the team agrees on schema, auth provider, and authority boundaries.

#### Week 2, iOS service layer and environment config

- Add a real API client layer in the app.
- Create environment-based configuration for base URL, anon key, and feature flags.
- Stop treating `ContentService` as bundle-only.
- Keep bundle JSON as development fallback, not the primary source.
- Add structured logging categories for auth, content sync, AR, and check-ins.
- Exit criteria: the app can boot with environment config and instantiate a live service stack.

#### Week 3, remote content read path

- Implement remote fetch for campus config, events, pins, and collectibles.
- Cache remote payloads into SwiftData or a local decoded cache model.
- Add content freshness metadata such as `lastSyncedAt` and content version.
- Define fallback behavior when network is unavailable.
- Exit criteria: launch uses remote content when available and local fallback when not.

#### Week 4, startup hardening and observability

- Expand startup state handling in `LaunchGateView` and `ModelController`.
- Distinguish startup failures from partial content failures.
- Add retry behavior, stale content messaging, and analytics for launch outcomes.
- Add a basic staging smoke checklist for launch, permissions, content sync, and cached reopen.
- Exit criteria: startup flow is stable enough for repeated internal testing.

### Month 2, Identity And Player State

#### Week 5, authentication foundation

- Implement sign in using Apple, Google, or campus email magic link.
- Create a server-backed player record on first sign in.
- Add token restore on app launch.
- Define anonymous behavior if guests are allowed.
- Exit criteria: a real user can sign in and persist a session.

#### Week 6, player profile sync

- Replace local seeded user assumptions in `ModelController` with authenticated profile load.
- Sync display name, avatar type, avatar color, and player metadata from backend.
- Keep avatar editing in `ProfileScreen`, but write changes through the backend.
- Exit criteria: profile data round-trips between app and backend.

#### Week 7, collection and progress sync

- Load collection history from backend at launch.
- Persist collected count and total points from backend responses, not client-side estimates.
- Merge or replace local seed progress depending on migration strategy.
- Define cross-device conflict resolution.
- Exit criteria: a user sees the same progress on multiple devices.

#### Week 8, auth edge cases and account lifecycle

- Add sign out behavior that clears sensitive session state but preserves safe caches.
- Handle expired sessions, deleted accounts, and token refresh failure.
- Add profile recovery and account relink rules if multiple providers are supported.
- Exit criteria: session lifecycle is predictable and testable.

### Month 3, Live Event And Map Functionality

#### Week 9, schedule and pins go live

- Replace static `Database.events` and `Database.pins` as primary runtime sources.
- Add event states: draft, scheduled, live, ended, cancelled, hidden.
- Add time windows and visibility rules.
- Exit criteria: Home, Schedule, Map, and Event Detail all render live backend data.

#### Week 10, map behavior and live eligibility

- Add backend fields for pin activation, event linkage, collectible enablement, and availability windows.
- Update `MapScreen` to reflect live statuses and unavailable states.
- Add UI states for too early, too far, inactive, and completed.
- Exit criteria: the map no longer assumes every configured pin is always active.

#### Week 11, event check-in flow

- Implement event attendance or check-in endpoint.
- Validate by time window and proximity.
- Optionally support QR code plus location for stronger validation.
- Award check-in points on the server.
- Exit criteria: a user can attend a real event and receive verified credit.

#### Week 12, leaderboard and summaries

- Implement backend leaderboard aggregation.
- Replace client-local ranking assumptions.
- Add weekly, daily, and overall leaderboard modes if needed.
- Add server summaries for profile stats and home dashboard highlights.
- Exit criteria: ranking and profile summaries come from authoritative backend state.

### Month 4, Server Validated AR Gameplay

#### Week 13, collectible domain cleanup

- Give collectibles stable backend IDs and stop relying on names as identity.
- Link pins and events to collectible pools by ID.
- Add rarity, active windows, point values, and spawn rules on the backend.
- Exit criteria: collectible identity is stable across app releases.

#### Week 14, AR claim protocol

- Add a capture claim request from `ARCollectibleExperienceView`.
- Submit collectible ID, pin ID, event ID if applicable, timestamp, and device location snapshot.
- Return a typed server result: success, duplicate, too far, expired, invalid, suspicious, retryable failure.
- Exit criteria: the app asks the server before awarding rewards.

#### Week 15, anti-cheat and rule enforcement

- Add distance validation, duplicate protection, time window checks, and basic impossible-travel rules.
- Add server-side logging for suspicious capture attempts.
- Add moderation fields to review captures after the fact if necessary.
- Exit criteria: obvious abuse paths are blocked.

#### Week 16, capture UX polish and failure recovery

- Update UI to show pending, success, duplicate, and network error states.
- Add retry behavior for transient network issues.
- Make collection updates reflect server receipts instead of speculative local awards.
- Exit criteria: capture flow feels reliable during real testing.

### Month 5, Operations, Admin, And Launch Readiness

#### Week 17, admin content operations

- Create a minimal admin workflow for events, pins, collectible pools, and visibility toggles.
- Add the ability to fix points or grant manual rewards.
- Exit criteria: event staff can operate the experience without needing app code changes.

#### Week 18, notifications and messaging

- Add push notifications for event reminders, limited-time drops, and ranking changes.
- Add remote announcement content for urgent changes such as moved locations or cancelled events.
- Exit criteria: operators can reach users without an app update.

#### Week 19, QA matrix and pilot prep

- Run a full on-campus pilot.
- Test degraded GPS, denied permissions, app relaunch mid-capture, offline reopen, and backend outage behavior.
- Fix the issues found in the pilot before broad launch.
- Exit criteria: known critical bugs are resolved or accepted explicitly.

#### Week 20, release hardening

- Freeze schema version 1.
- Finalize production analytics dashboards.
- Verify staging to production rollout plan.
- Prepare support runbook and rollback plan.
- Exit criteria: the app is ready for a real event week with live operations.

## Backend Schema Plan

The schema below is relational, because the app has clear relationships between users, events, pins, collectibles, and reward claims.

### Core Tables

#### `users`

Purpose: identity and account record.

Fields:

- `id` UUID primary key
- `auth_provider` text
- `auth_subject` text unique
- `email` text nullable
- `display_name` text
- `avatar_type` text
- `avatar_color_hex` text
- `role` text default `player`
- `status` text default `active`
- `created_at` timestamptz
- `updated_at` timestamptz
- `last_seen_at` timestamptz nullable

#### `player_profiles`

Purpose: app-specific player state separated from auth identity.

Fields:

- `user_id` UUID primary key references `users(id)`
- `total_points` integer default 0
- `collected_count` integer default 0
- `check_in_count` integer default 0
- `badge_count` integer default 0
- `campus_rank_cached` integer nullable
- `season_id` UUID nullable
- `created_at` timestamptz
- `updated_at` timestamptz

#### `seasons`

Purpose: support multiple Henson Day runs over time.

Fields:

- `id` UUID primary key
- `slug` text unique
- `name` text
- `starts_at` timestamptz
- `ends_at` timestamptz
- `status` text
- `created_at` timestamptz
- `updated_at` timestamptz

#### `events`

Purpose: live schedule entries and gameplay anchors.

Fields:

- `id` UUID primary key
- `season_id` UUID references `seasons(id)`
- `slug` text unique
- `title` text
- `description` text
- `location_name` text
- `latitude` double precision
- `longitude` double precision
- `starts_at` timestamptz
- `ends_at` timestamptz
- `status` text
- `pin_type` text
- `visibility` text default `public`
- `check_in_radius_meters` integer nullable
- `check_in_points` integer default 0
- `hero_image_url` text nullable
- `created_at` timestamptz
- `updated_at` timestamptz

#### `pins`

Purpose: map-visible locations that may or may not be tied to events.

Fields:

- `id` UUID primary key
- `season_id` UUID references `seasons(id)`
- `event_id` UUID nullable references `events(id)`
- `title` text
- `subtitle` text nullable
- `description` text
- `latitude` double precision
- `longitude` double precision
- `pin_type` text
- `status` text
- `is_hidden` boolean default false
- `activation_starts_at` timestamptz nullable
- `activation_ends_at` timestamptz nullable
- `has_ar_collectible` boolean default false
- `created_at` timestamptz
- `updated_at` timestamptz

#### `collectibles`

Purpose: canonical collectible definitions.

Fields:

- `id` UUID primary key
- `season_id` UUID references `seasons(id)`
- `slug` text unique
- `name` text
- `rarity` text
- `model_file_name` text
- `image_url` text nullable
- `flavor_text` text
- `points` integer
- `cp` integer
- `is_active` boolean default true
- `created_at` timestamptz
- `updated_at` timestamptz

#### `collectible_types`

Purpose: normalize the current `types: [String]` field for filtering and expansion.

Fields:

- `collectible_id` UUID references `collectibles(id)`
- `type_name` text

Primary key:

- `collectible_id`, `type_name`

#### `pin_collectibles`

Purpose: which collectibles can spawn at which pins.

Fields:

- `pin_id` UUID references `pins(id)`
- `collectible_id` UUID references `collectibles(id)`
- `spawn_weight` integer default 1
- `starts_at` timestamptz nullable
- `ends_at` timestamptz nullable
- `max_claims_per_user` integer nullable

Primary key:

- `pin_id`, `collectible_id`

#### `event_collectibles`

Purpose: event-specific collectible availability, when event logic differs from map pin logic.

Fields:

- `event_id` UUID references `events(id)`
- `collectible_id` UUID references `collectibles(id)`
- `starts_at` timestamptz nullable
- `ends_at` timestamptz nullable
- `bonus_points` integer nullable

Primary key:

- `event_id`, `collectible_id`

#### `check_ins`

Purpose: verified attendance and event rewards.

Fields:

- `id` UUID primary key
- `user_id` UUID references `users(id)`
- `event_id` UUID references `events(id)`
- `method` text
- `device_latitude` double precision nullable
- `device_longitude` double precision nullable
- `distance_meters` double precision nullable
- `awarded_points` integer default 0
- `result` text
- `checked_in_at` timestamptz
- `created_at` timestamptz

Constraint:

- unique `user_id`, `event_id` when only one check-in is allowed

#### `collectible_claims`

Purpose: server-authoritative collectible capture log.

Fields:

- `id` UUID primary key
- `user_id` UUID references `users(id)`
- `collectible_id` UUID references `collectibles(id)`
- `pin_id` UUID nullable references `pins(id)`
- `event_id` UUID nullable references `events(id)`
- `device_latitude` double precision nullable
- `device_longitude` double precision nullable
- `distance_meters` double precision nullable
- `claim_source` text
- `awarded_points` integer default 0
- `result` text
- `suspicion_score` integer default 0
- `claimed_at` timestamptz
- `created_at` timestamptz

Recommended constraint:

- unique `user_id`, `collectible_id`, `pin_id` when each pin collectible can only be earned once

#### `badges`

Purpose: badge catalog.

Fields:

- `id` UUID primary key
- `slug` text unique
- `name` text
- `description` text
- `icon_name` text
- `is_active` boolean default true

#### `user_badges`

Purpose: granted badges.

Fields:

- `user_id` UUID references `users(id)`
- `badge_id` UUID references `badges(id)`
- `awarded_at` timestamptz
- `source` text

Primary key:

- `user_id`, `badge_id`

#### `announcements`

Purpose: remote content and operational messaging.

Fields:

- `id` UUID primary key
- `title` text
- `body` text
- `audience` text
- `starts_at` timestamptz nullable
- `ends_at` timestamptz nullable
- `priority` text
- `is_active` boolean default true
- `created_at` timestamptz

#### `campus_config`

Purpose: runtime app configuration.

Fields:

- `id` UUID primary key
- `campus_name` text
- `center_latitude` double precision
- `center_longitude` double precision
- `default_spawn_radius_meters` integer
- `map_span_latitude_delta` double precision
- `map_span_longitude_delta` double precision
- `active_season_id` UUID nullable references `seasons(id)`
- `updated_at` timestamptz

### Derived Views Or Materialized Views

#### `leaderboard_view`

Columns:

- `user_id`
- `display_name`
- `avatar_type`
- `avatar_color_hex`
- `total_points`
- `collected_count`
- `check_in_count`
- `rank`

#### `event_summary_view`

Columns:

- `event_id`
- `check_in_count`
- `claim_count`
- `unique_players`

### Audit And Anti-Abuse Support

Recommended additional tables once the core loop works:

- `suspicious_activity_events`
- `admin_actions`
- `notification_deliveries`
- `sync_failures`

## API Plan

The app needs a small, opinionated API surface. The goal is stable gameplay APIs, not generic CRUD from the device.

### Auth

#### `POST /auth/sign-in`

Use provider token exchange if auth is not fully delegated to Supabase client SDK.

Response:

- session token
- user profile summary

#### `POST /auth/sign-out`

Optional if server-side session revocation is needed.

#### `GET /me`

Returns:

- account profile
- player profile summary
- current season info

#### `PATCH /me/profile`

Request fields:

- `displayName`
- `avatarType`
- `avatarColorHex`

### Content Sync

#### `GET /bootstrap`

Best first-launch endpoint.

Returns:

- campus config
- current season
- announcements
- content version
- feature flags

#### `GET /events`

Query params:

- `seasonId`
- `status`
- `updatedAfter`

Returns:

- event list with live state metadata

#### `GET /events/{eventId}`

Returns:

- event details
- linked collectible info
- eligibility summary if authenticated

#### `GET /pins`

Query params:

- `seasonId`
- `updatedAfter`
- `visibleOnly`

#### `GET /collectibles`

Query params:

- `seasonId`
- `updatedAfter`

#### `GET /announcements`

Returns active remote messages and urgent content.

### Player Progress

#### `GET /me/dashboard`

Returns:

- total points
- collected count
- rank
- next event
- current announcements

#### `GET /me/collection`

Returns:

- collected items
- claim receipts
- collectible metadata needed for the Collection screen

#### `GET /leaderboard`

Query params:

- `seasonId`
- `scope`
- `limit`

Returns:

- ranked rows
- current user row if outside top limit

### Gameplay Actions

#### `POST /events/{eventId}/check-in`

Request:

- `method`
- `deviceLatitude`
- `deviceLongitude`
- `scannedCode` nullable
- `clientTimestamp`

Response:

- `result`
- `awardedPoints`
- `updatedProfile`
- `message`

Server result enums:

- `success`
- `alreadyCheckedIn`
- `tooFar`
- `tooEarly`
- `expired`
- `invalidCode`
- `notAllowed`
- `retryableError`

#### `POST /collectible-claims`

Request:

- `collectibleId`
- `pinId` nullable
- `eventId` nullable
- `deviceLatitude`
- `deviceLongitude`
- `clientTimestamp`
- `claimSource`

Response:

- `result`
- `awardedPoints`
- `updatedProfile`
- `claimReceipt`
- `message`

Server result enums:

- `success`
- `duplicate`
- `tooFar`
- `inactive`
- `expired`
- `invalidPin`
- `invalidEvent`
- `suspicious`
- `retryableError`

### Admin And Ops

These do not need to ship in the iOS app first, but the backend should be ready for them.

#### `POST /admin/events`
#### `PATCH /admin/events/{eventId}`
#### `POST /admin/pins`
#### `PATCH /admin/pins/{pinId}`
#### `POST /admin/announcements`
#### `POST /admin/rewards/manual-grant`

### Sync Strategy

Recommended client sync approach:

- On launch, call `GET /bootstrap` and `GET /me` after session restore.
- Then fetch delta updates using `updatedAfter` timestamps.
- Cache server payloads locally.
- Keep a `contentVersion` marker to detect incompatible payload changes.
- Never let the client directly compute permanent point rewards without server confirmation.

## Concrete Implementation Roadmap Mapped To Existing Swift Files

This section maps the product plan into the current codebase so work can start without a major rewrite.

### App Entry And Composition

#### `Henson_Day/HensonDayApp.swift`

Current role:

- builds global environment objects
- loads bundled content on startup

Planned changes:

- add `AppEnvironment` or `ConfigurationManager`
- inject `AuthService`, `APIClient`, `SessionStore`, `ContentRepository`, and `GameplayService`
- move startup bootstrapping into a coordinated startup task instead of calling only `contentService.loadFromBundle()` and `refreshFromRemoteIfAvailable()`

Implementation notes:

- Keep this file thin.
- Construct shared services here, but keep business logic out.

### Core State And Repositories

#### `Henson_Day/Models/ModelController.swift`

Current role:

- owns SwiftData container
- seeds local data
- exposes current user, pins, leaderboard, schedule, collectibles
- mutates collection state locally

Planned changes:

- split seeding logic from runtime sync logic
- stop using `Database` as the primary production source
- replace local-only `captureCollectible` success path with server receipt processing
- load user profile, leaderboard, events, pins, and collection through repositories
- store server sync timestamps and cache freshness state
- add async methods such as:
  - `bootstrap()`
  - `refreshContent()`
  - `refreshPlayerState()`
  - `submitCheckIn(eventID:)`
  - `submitCollectibleClaim(...)`

Implementation notes:

- This file is the best current place to coordinate UI-facing state.
- Over time, it should become an orchestrator, not a bag of direct persistence logic.

#### `Henson_Day/Views/ContentService.swift`

Current role:

- loads bundled JSON seeds
- has a placeholder remote refresh method

Planned changes:

- rename or evolve into a repository layer that handles remote plus local cache
- add decoded DTOs for events, pins, collectibles, characters, location assets, and narrative nodes
- implement real remote fetch, schema version checks, and merge behavior
- store metadata like `lastSuccessfulSyncAt` and `contentVersion`

Implementation notes:

- This is the cleanest seam for live content and should be implemented early.

#### `Henson_Day/Models/CampusConfigProvider.swift`

Current role:

- exposes a local fallback campus center

Planned changes:

- back this with remote `campus_config`
- support cached remote config plus bundled fallback
- add map span and gameplay radius config values

Implementation notes:

- Keep fallback behavior because it will help when network fails during pilot use.

#### `Henson_Day/Models/Database.swift`

Current role:

- stores hardcoded players, events, pins, and collectibles

Planned changes:

- keep as development seed and preview data only
- remove its role as the default runtime source in production code paths
- use it for SwiftUI previews and emergency offline demo mode if desired

Implementation notes:

- Do not delete this too early. It remains useful for preview stability and local design work.

#### `Henson_Day/Models/PersistenceModels.swift`

Current role:

- defines cached player, pin, badge, and collected item models in SwiftData

Planned changes:

- expand models or add parallel cache models for remote IDs, sync timestamps, and backend statuses
- add stable backend ID fields to entities that currently rely on names or local UUIDs
- consider adding cache entities for `EventCacheEntity`, `CollectibleCacheEntity`, and `AnnouncementCacheEntity`

Implementation notes:

- If SwiftData remains the cache, it needs backend identifiers everywhere.

### Auth And Profile

#### `Henson_Day/Views/ProfileScreen.swift`

Current role:

- displays local profile stats
- edits avatar locally
- shows a placeholder sign out action

Planned changes:

- bind to authenticated profile data
- call backend profile update endpoint when avatar or name changes
- make sign out real
- add session and account state messaging

Implementation notes:

- Keep this screen as the main player settings surface.
- Add optimistic UI only for cosmetic changes, not gameplay state.

#### `Henson_Day/Models/UserDatabase.swift`

Current role:

- computes simple profile snapshots from `ModelController`

Planned changes:

- keep as a thin projection helper or replace with dedicated view models
- stop deriving critical rank and stats from incomplete local state when backend summaries exist

### Startup And Permissions

#### `Henson_Day/Views/LaunchGateView.swift`

Current role:

- handles initial camera and location permission prompting
- gates entry into the app
- displays startup seed loading and retry UI

Planned changes:

- add auth restore state to startup flow
- support partial-capability entry, for example map browsing without camera capture
- surface stale content status separately from fatal startup failure
- distinguish between auth failure, sync failure, and permissions limitations

Implementation notes:

- The current flow is good enough structurally. It just needs more startup states.

### Home, Schedule, And Event Surfaces

#### `Henson_Day/Views/HomeScreen.swift`

Current role:

- shows next event and local stat summaries

Planned changes:

- use backend dashboard payload for next event, alerts, and player summary
- add announcement cards or limited-time event highlights
- surface current live event status

#### `Henson_Day/Views/EventDetailScreen.swift`

Current role:

- renders a hardcoded-style event detail from local event data
- shows a collectible summary and a capture shortcut

Planned changes:

- support live event state, attendance status, and eligibility summary
- add real check-in action and response states
- replace placeholder attendee metadata with server-backed summary if needed
- ensure collectible details use backend IDs and real availability windows

Implementation notes:

- This file becomes the best place to host event check-in UX.

### Map And Location Gameplay

#### `Henson_Day/Views/MapScreen.swift`

Current role:

- renders pins
- opens detail sheets
- launches AR flow
- has a testing teleport mode

Planned changes:

- respect server-side pin availability and event activation windows
- prevent AR launch when eligibility fails, unless allowed for preview mode
- add status badges like live, upcoming, checked in, already captured
- wire pin detail actions to check-in or capture eligibility endpoints

Implementation notes:

- Keep teleport testing behind debug flags only.
- Do not ship testing override behavior in release builds.

#### `Henson_Day/Models/LocationManager.swift`
#### `Henson_Day/Models/ProximityMonitor.swift`

Current role:

- location and proximity support

Planned changes:

- standardize the location snapshot used for check-ins and collectible claims
- record accuracy and timestamp so the server can judge whether the sample is trustworthy
- add graceful handling for poor GPS accuracy

### AR Capture Flow

#### `Henson_Day/Views/ARCollectibleExperienceView.swift`

Current role:

- decides proximity eligibility locally
- places collectible models
- awards collection locally through `ModelController`

Planned changes:

- keep local proximity and placement as UI guidance only
- submit a capture claim to the backend before final reward is confirmed
- use server response to transition into captured, duplicate, too-far, or invalid states
- attach backend collectible IDs to the active collectible, not only names

Implementation notes:

- This file is the center of the real gameplay transition from prototype to production.

#### `Henson_Day/Views/ARCaptureScreen.swift`
#### `Henson_Day/Views/ARCameraView.swift`
#### `Henson_Day/Views/ARCanvasView.swift`

Current role:

- camera and AR experience helpers

Planned changes:

- keep rendering and placement responsibilities here
- do not let these files own scoring rules
- add clearer pending-network and retry states if capture submission happens from these layers

### Collection And Leaderboard

#### `Henson_Day/Views/CollectionScreen.swift`

Current role:

- shows collected items from local state plus full collectible catalog

Planned changes:

- drive collected status from backend-synced claim receipts
- add server metadata such as claim date, source pin, event, and locked reasons if useful
- handle partially synced states cleanly when offline

Implementation notes:

- This screen should remain fast, so local cache still matters even after backend sync exists.

#### `Henson_Day/Views/LeaderboardScreen.swift`

Current role:

- likely displays local ranking derived from cached player data

Planned changes:

- use backend leaderboard endpoint
- support pagination or top-N plus current-user row
- add leaderboard period selector only if product actually needs it

### Navigation And Shared App Flow

#### `Henson_Day/Models/TabRouter.swift`

Current role:

- manages selected tab and focused schedule event

Planned changes:

- keep mostly unchanged
- possibly add routes for auth or deep links from notifications

## Recommended New Files

These files would make the transition cleaner without forcing a full rewrite.

### Suggested service files

- `Henson_Day/Services/APIClient.swift`
- `Henson_Day/Services/AuthService.swift`
- `Henson_Day/Services/SessionStore.swift`
- `Henson_Day/Services/ContentRepository.swift`
- `Henson_Day/Services/ProfileRepository.swift`
- `Henson_Day/Services/GameplayService.swift`
- `Henson_Day/Services/LeaderboardRepository.swift`
- `Henson_Day/Services/ConfigService.swift`

### Suggested model files

- `Henson_Day/Models/APIModels.swift`
- `Henson_Day/Models/SyncState.swift`
- `Henson_Day/Models/RemoteConfig.swift`
- `Henson_Day/Models/GameplayResult.swift`

## Recommended First Sprint

If implementation starts immediately, the first sprint should do only these things:

1. Add environment config plus `APIClient`.
2. Implement `GET /bootstrap`, `GET /events`, `GET /pins`, and `GET /collectibles`.
3. Refactor `ContentService` to fetch and cache remote content.
4. Update `ModelController` to read events, pins, and collectibles from the new repository.
5. Keep `Database.swift` as fallback and preview seed data.

That sprint would turn the app from static content into a live content app without yet taking on the full auth and gameplay validation surface.

## Definition Of Done For Real Functionality

The app should be considered meaningfully real, not just visually complete, when all of the following are true:

- a real user can sign in and restore their session
- events and pins are remotely managed
- check-ins are server verified
- collectible rewards are server verified
- leaderboard rank comes from the backend
- content can be updated without shipping a new app build
- the app remains usable in degraded offline conditions
- event staff can operate the experience during a live week