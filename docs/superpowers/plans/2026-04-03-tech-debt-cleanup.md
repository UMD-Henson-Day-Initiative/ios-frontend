# Tech Debt Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix remaining tech debt issues: duplicate StateObject in ARMapContainerView, RouteManager error handling, hardcoded values, @MainActor documentation, comments/docstrings, and README file inventory.

**Architecture:** Minimal-touch cleanup across Models/ and Views/. No new frameworks or patterns — just fixing what's already there. Constants extraction to existing AppConstants.swift, error handling aligned with existing UserFacingErrorState pattern, documentation added to bare files.

**Tech Stack:** SwiftUI, SwiftData, MapKit, RealityKit, CoreLocation

---

## File Structure

**Files to modify:**
- `Henson_Day/Views/ARMapContainerView.swift` — change @StateObject to @EnvironmentObject
- `Henson_Day/Models/RouteManager.swift` — add error state, fix @MainActor
- `Henson_Day/Models/AppConstants.swift` — add new constant sections
- `Henson_Day/Views/MapView.swift` — extract hardcoded values to AppConstants
- `Henson_Day/Models/ProximityMonitor.swift` — extract hardcoded values to AppConstants
- `Henson_Day/Views/ARCollectibleExperienceView.swift` — extract default points, add docs
- `Henson_Day/Views/ScheduleScreen.swift` — extract hardcoded URL
- `Henson_Day/Models/ModelController.swift` — add @MainActor rationale comment
- `Henson_Day/Models/PersistenceModels.swift` — add docstrings
- `Henson_Day/Models/Database.swift` — add docstrings
- `Henson_Day/Models/TabRouter.swift` — add docstrings
- `Henson_Day/Models/MapPinDetail.swift` — add docstrings
- `Henson_Day/Models/UserDatabase.swift` — add docstrings
- `Henson_Day/Views/LaunchGateView.swift` — add docstrings
- `Henson_Day/Views/CollectionScreen.swift` — add docstrings
- `Henson_Day/Views/PinDetailBottomSheet.swift` — add docstrings
- `README.md` — add file inventory section

**Files to delete (dead code):**
- `Henson_Day/Views/HensonCameraRootView.swift` — not referenced anywhere in the app

---

### Task 1: Fix ARMapContainerView duplicate StateObject

**Files:**
- Modify: `Henson_Day/Views/ARMapContainerView.swift:6-8`

The 3 managers are already created in `HensonDayApp.swift:9-11` and injected as `.environmentObject()`. `MapScreen.swift` already uses `@EnvironmentObject` for them. `ARMapContainerView` is the only remaining view that creates duplicate instances.

- [ ] **Step 1: Replace @StateObject with @EnvironmentObject in ARMapContainerView**

Change lines 6-8 from:
```swift
@StateObject private var cameraPermission = CameraPermissionManager()
@StateObject private var locationManager = LocationPermissionManager()
@StateObject private var worldAnchorManager = WorldAnchorManager()
```
to:
```swift
@EnvironmentObject private var cameraPermission: CameraPermissionManager
@EnvironmentObject private var locationManager: LocationPermissionManager
@EnvironmentObject private var worldAnchorManager: WorldAnchorManager
```

- [ ] **Step 2: Delete dead code HensonCameraRootView.swift**

`HensonCameraRootView` is only referenced by its own Preview — no other file uses it. It wraps `ARMapContainerView` but is never instantiated. Delete `Henson_Day/Views/HensonCameraRootView.swift`.

Also remove it from the Xcode project file if it's referenced there.

- [ ] **Step 3: Verify build**

Run:
```bash
xcodebuild -project Henson_Day.xcodeproj -scheme Henson_Day -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Henson_Day/Views/ARMapContainerView.swift
git rm Henson_Day/Views/HensonCameraRootView.swift
git commit -m "fix: remove duplicate StateObject managers from ARMapContainerView

ARMapContainerView was creating its own instances of CameraPermissionManager,
LocationPermissionManager, and WorldAnchorManager instead of using the ones
injected from HensonDayApp. Changed to @EnvironmentObject.

Also deleted unused HensonCameraRootView.swift (dead code)."
```

---

### Task 2: Fix RouteManager error handling

**Files:**
- Modify: `Henson_Day/Models/RouteManager.swift`

RouteManager uses the existing `UserFacingErrorState` struct from ModelController.swift. Add a `@Published var routeError: UserFacingErrorState?` and replace the `print()` in the catch block.

- [ ] **Step 1: Add error state property and clear method**

Add after line 17 (`@Published var isNavigating: Bool = false`):
```swift
@Published var routeError: UserFacingErrorState?

func clearRouteError() {
    routeError = nil
}
```

- [ ] **Step 2: Replace print-only catch with proper error state**

Change lines 52-54 from:
```swift
} catch {
    print("Route calculation failed: \(error)")
}
```
to:
```swift
} catch {
    routeError = UserFacingErrorState(
        title: "Directions unavailable",
        message: "Couldn't calculate walking directions. Check your connection and try again."
    )
}
```

- [ ] **Step 3: Verify build**

Run:
```bash
xcodebuild -project Henson_Day.xcodeproj -scheme Henson_Day -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Henson_Day/Models/RouteManager.swift
git commit -m "fix: add proper error state to RouteManager instead of print-only catch"
```

---

### Task 3: Extract hardcoded values to AppConstants

**Files:**
- Modify: `Henson_Day/Models/AppConstants.swift`
- Modify: `Henson_Day/Views/MapView.swift`
- Modify: `Henson_Day/Models/ProximityMonitor.swift`
- Modify: `Henson_Day/Models/RouteManager.swift`
- Modify: `Henson_Day/Views/ARCollectibleExperienceView.swift`
- Modify: `Henson_Day/Views/ScheduleScreen.swift`

- [ ] **Step 1: Add new constants to AppConstants.swift**

Add the following inside `enum AppConstants`:

After the existing `Map` enum (around line 20), add these new entries inside it:
```swift
// Campus boundary coordinates used by MapView camera bounds.
static let campusBoundsMinLat = 38.981086
static let campusBoundsMaxLat = 38.994498
static let campusBoundsMinLon = -76.954429
static let campusBoundsMaxLon = -76.934774

static let cameraMinDistance: Double = 50
static let cameraMaxDistance: Double = 3000
static let defaultCameraDistance: Double = 350
static let defaultCameraPitch: Double = 55
static let followLossThreshold: Double = 0.0005
```

Add these inside the existing `AR` enum:
```swift
static let proximityRadiusMeters: CLLocationDistance = 10
static let proximityDebounceMilliseconds: Int = 500
static let defaultCollectiblePoints: Int = 50
```

Add a new section at the bottom of the file:
```swift
enum Route {
    static let stepAdvanceDistanceMeters: CLLocationDistance = 15
    static let arrivalDistanceMeters: CLLocationDistance = 20
}

enum URLs {
    static let universityHome = "https://umd.edu/"
}
```

- [ ] **Step 2: Update MapView.swift to use AppConstants**

Replace lines 14-17:
```swift
static let minLat = 38.981086
static let maxLat = 38.994498
static let minLon = -76.954429
static let maxLon = -76.934774
```
with:
```swift
static let minLat = AppConstants.Map.campusBoundsMinLat
static let maxLat = AppConstants.Map.campusBoundsMaxLat
static let minLon = AppConstants.Map.campusBoundsMinLon
static let maxLon = AppConstants.Map.campusBoundsMaxLon
```

Replace `minimumDistance: 50` (line 32) with `minimumDistance: AppConstants.Map.cameraMinDistance`

Replace `maximumDistance: 3000` (line 33) with `maximumDistance: AppConstants.Map.cameraMaxDistance`

Replace both `distance: 350` (lines 38 and 42) with `distance: AppConstants.Map.defaultCameraDistance`

Replace `pitch: 55` (line 44) with `pitch: AppConstants.Map.defaultCameraPitch`

Find all other occurrences of `cameraDistance` being set to `350` and replace with `AppConstants.Map.defaultCameraDistance`. Check lines ~171 and ~177.

Replace `0.0005` (line 107) with `AppConstants.Map.followLossThreshold`.

- [ ] **Step 3: Update ProximityMonitor.swift to use AppConstants**

Replace line 19:
```swift
private let proximityRadius: CLLocationDistance = 10
```
with:
```swift
private let proximityRadius: CLLocationDistance = AppConstants.AR.proximityRadiusMeters
```

Replace `.milliseconds(500)` (line 27) with `.milliseconds(AppConstants.AR.proximityDebounceMilliseconds)`.

- [ ] **Step 4: Update RouteManager.swift to use AppConstants**

Replace `< 15` (line 73) with `< AppConstants.Route.stepAdvanceDistanceMeters`.

Replace `< 20` (line 78) with `< AppConstants.Route.arrivalDistanceMeters`.

- [ ] **Step 5: Update ARCollectibleExperienceView.swift to use AppConstants**

Replace `?? 50` (line 53) with `?? AppConstants.AR.defaultCollectiblePoints`.

- [ ] **Step 6: Update ScheduleScreen.swift to use AppConstants**

Replace `"https://umd.edu/"` (line 80) with `AppConstants.URLs.universityHome`.

- [ ] **Step 7: Verify build**

Run:
```bash
xcodebuild -project Henson_Day.xcodeproj -scheme Henson_Day -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED

- [ ] **Step 8: Commit**

```bash
git add Henson_Day/Models/AppConstants.swift Henson_Day/Views/MapView.swift Henson_Day/Models/ProximityMonitor.swift Henson_Day/Models/RouteManager.swift Henson_Day/Views/ARCollectibleExperienceView.swift Henson_Day/Views/ScheduleScreen.swift
git commit -m "refactor: extract hardcoded values to AppConstants

Move campus bounds, camera distances, proximity radius, route thresholds,
default collectible points, and university URL to centralized constants."
```

---

### Task 4: Document @MainActor usage rationale

**Files:**
- Modify: `Henson_Day/Models/ModelController.swift`
- Modify: `Henson_Day/Models/RouteManager.swift`

The @MainActor on ModelController is actually correct for SwiftData — `ModelContext` is not thread-safe and must be used on the same actor it was created on. Since the dataset is small (~90 pins, handful of players), the performance impact is negligible. Add a comment documenting this decision rather than refactoring to background contexts.

For RouteManager, `MKDirections.calculate()` is `async` and suspends properly, so @MainActor is acceptable. Add a comment.

- [ ] **Step 1: Add rationale comment to ModelController.swift**

Add before line 13 (`@MainActor`):
```swift
// NOTE: @MainActor is intentional. SwiftData's ModelContext is not thread-safe
// and must be accessed from the actor it was created on. For the current dataset
// size (~90 pins, ~10 players), main-thread SwiftData ops have no measurable
// UI impact. If the dataset grows significantly, consider creating a background
// ModelContext via ModelContext(container) on a detached task.
```

- [ ] **Step 2: Add rationale comment to RouteManager.swift**

Add before line 12 (`@MainActor`):
```swift
// NOTE: @MainActor is acceptable here. MKDirections.calculate() is async and
// properly suspends without blocking the main thread. All @Published properties
// drive UI, so main-actor isolation simplifies state updates.
```

- [ ] **Step 3: Commit**

```bash
git add Henson_Day/Models/ModelController.swift Henson_Day/Models/RouteManager.swift
git commit -m "docs: add @MainActor rationale comments to ModelController and RouteManager"
```

---

### Task 5: Add comments and docstrings to undocumented files

**Files:**
- Modify: `Henson_Day/Models/PersistenceModels.swift`
- Modify: `Henson_Day/Models/Database.swift`
- Modify: `Henson_Day/Models/TabRouter.swift`
- Modify: `Henson_Day/Models/MapPinDetail.swift`
- Modify: `Henson_Day/Models/UserDatabase.swift`
- Modify: `Henson_Day/Views/LaunchGateView.swift`
- Modify: `Henson_Day/Views/ARCollectibleExperienceView.swift`
- Modify: `Henson_Day/Views/CollectionScreen.swift`
- Modify: `Henson_Day/Views/ScheduleScreen.swift`
- Modify: `Henson_Day/Views/PinDetailBottomSheet.swift`

For each file, add:
1. A file-level `///` comment explaining what the file does
2. `///` docstrings on all public/internal types (structs, classes, enums)
3. `///` docstrings on non-trivial public/internal methods
4. Inline comments on non-obvious logic

Focus on "why" not "what" — don't comment obvious things like `var name: String`.

- [ ] **Step 1: Read each file and add docstrings**

Read each file in its entirety before adding comments. For each file:

**PersistenceModels.swift** — Document each SwiftData `@Model` entity, explain the raw-value enum pattern (e.g., `pinTypeRaw` stored as String with computed `pinType` wrapper), and note cascade/relationship behavior.

**Database.swift** — Document that this is the static seed data source, explain the relationship between `DatabasePin`, `DatabaseCollectible`, `DatabaseEvent` structs and their SwiftData counterparts, and note that `campusCenterFallback` is the UMD campus center.

**TabRouter.swift** — Document the cross-tab navigation pattern, explain `focusedScheduleEventID` for deep-linking from map pins to schedule events.

**MapPinDetail.swift** — Document `PinType` enum values and their visual representation (color, SF Symbol), explain `MapPinDetail` as the view-model bridging PinEntity to the bottom sheet.

**UserDatabase.swift** — Document helper functions and their purpose.

**LaunchGateView.swift** — Document the permission gate flow: check camera + location → show status → allow retry or open Settings → transition to `RootTabView`.

**ARCollectibleExperienceView.swift** — Document the AR state machine: approach → spawn → capture → collect. Add inline comments on the proximity calculation, teleport flow, and model loading pipeline.

**CollectionScreen.swift** — Document the collection catalog display and filtering logic.

**ScheduleScreen.swift** — Document event filtering by day and category.

**PinDetailBottomSheet.swift** — Document the drag-to-dismiss gesture, the primary action routing by pin type, and the navigation/details callbacks.

- [ ] **Step 2: Verify build**

Run:
```bash
xcodebuild -project Henson_Day.xcodeproj -scheme Henson_Day -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Henson_Day/Models/PersistenceModels.swift Henson_Day/Models/Database.swift Henson_Day/Models/TabRouter.swift Henson_Day/Models/MapPinDetail.swift Henson_Day/Models/UserDatabase.swift Henson_Day/Views/LaunchGateView.swift Henson_Day/Views/ARCollectibleExperienceView.swift Henson_Day/Views/CollectionScreen.swift Henson_Day/Views/ScheduleScreen.swift Henson_Day/Views/PinDetailBottomSheet.swift
git commit -m "docs: add docstrings and comments to undocumented Swift files

Add file-level docs, type docstrings, method docstrings, and inline
comments explaining non-obvious logic across 10 files in Models/ and Views/."
```

---

### Task 6: Add file inventory to README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Read current README.md**

Read the full `README.md` to understand its current structure and find the right place to add the inventory.

- [ ] **Step 2: Add file inventory section**

Add a "## File Reference" section to README.md with a one-line description of every Swift file, organized by directory. Format:

```markdown
## File Reference

### Henson_Day/ (App Root)
| File | Description |
|------|-------------|
| `HensonDayApp.swift` | App entry point; creates and injects all environment objects |

### Henson_Day/Models/
| File | Description |
|------|-------------|
| `AppConstants.swift` | Centralized configuration constants for map, AR, routing, and URLs |
| `BadgeModel.swift` | Badge data model for achievement system |
| ... | ... |

### Henson_Day/Views/
| File | Description |
|------|-------------|
| `ARCameraView.swift` | RealityKit AR camera with tap-to-place and world anchors |
| ... | ... |
```

Include every `.swift` file in Models/ and Views/ with an accurate one-line description based on what you read in Task 5.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: add file inventory to README for onboarding new engineers"
```

---

## Verification

After all tasks are complete:

1. Full build passes:
```bash
xcodebuild -project Henson_Day.xcodeproj -scheme Henson_Day -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
```

2. No remaining duplicate @StateObject managers:
```bash
grep -rn "@StateObject.*CameraPermissionManager\|@StateObject.*LocationPermissionManager\|@StateObject.*WorldAnchorManager" Henson_Day/
```
Expected: zero results (all should be in HensonDayApp.swift only)

3. No print-only error handling:
```bash
grep -A1 "catch {" Henson_Day/ -r | grep "print("
```
Expected: zero results

4. No remaining fatalError:
```bash
grep -rn "fatalError" Henson_Day/
```
Expected: zero results
