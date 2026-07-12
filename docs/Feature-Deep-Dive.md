# PlanDay — Feature Deep Dive

This document is a detailed technical and functional breakdown of every feature in the PlanDay app. Written for learning and reference — explains what each feature does, how it is built, what files are involved, and the logic behind key decisions.

---

## Table of Contents

1. [App Launch Flow](#1-app-launch-flow)
2. [Onboarding](#2-onboarding)
3. [Profile System](#3-profile-system-netflix-style)
4. [Home Dashboard](#4-home-dashboard)
5. [Day Plan Builder](#5-day-plan-builder)
6. [Trip Builder (Multi-Day)](#6-trip-builder-multi-day)
7. [Route Optimizer](#7-route-optimizer)
8. [Drag-to-Reorder Route](#8-drag-to-reorder-route)
9. [GPS Route Optimisation](#9-gps-route-optimisation)
10. [MinHeap Algorithm](#10-minheap-algorithm)
11. [Day Itinerary](#11-day-itinerary)
12. [Stop Duration Editor](#12-stop-duration-editor)
13. [Navigation (Stop-by-Step)](#13-navigation-stop-by-step)
14. [Live GPS Navigation](#14-live-gps-navigation)
15. [Trip History](#15-trip-history)
16. [Plan Reminder Notifications](#16-plan-reminder-notifications)
17. [Settings & Appearance](#17-settings--appearance)
18. [Multi-User Profiles (Data Layer)](#18-multi-user-profiles-data-layer)
19. [Persistence Layer](#19-persistence-layer)
20. [Edit & Delete Plans](#20-edit--delete-plans)

---

## 1. App Launch Flow

### What it does
Every time the app opens, it decides which screen to show first based on several flags stored in UserDefaults.

### Files
- `DayPlannerApp.swift` — `@main` entry point
- `SplashScreenView.swift` — actual root of the view hierarchy
- `WelcomeScreenView.swift` — first-ever launch welcome
- `ProfileCreationView.swift` — first-ever profile setup
- `ProfileSelectionView.swift` — returning user profile picker

### Decision tree
```
App opens
  → SplashScreenView (always shown, 2.5 seconds)
      → hasSeenWelcomeScreen == false?
          → WelcomeScreenView (staggered animations)
              → "Get Started" → ProfileCreationView
      → profiles.count == 1 && name == "Me" (auto-default only)?
          → ProfileCreationView (first real profile setup)
      → else (returning user with real profiles):
          → ProfileSelectionView (Netflix-style grid)
              → Tap profile → HomeView
```

### Key implementation detail
`SplashScreenView` is the root of the view hierarchy (set in `DayPlannerApp.body`). This is why `preferredColorScheme` is applied here — it must sit at the very top to affect the whole app. `ContentView` still exists but is no longer used as the root.

### Animation
- Logo scales from 0.8 → 1.0 with `easeOut(duration: 0.6)`
- Tagline fades in at 0.8s delay
- Timer fires after 2.5s → `withAnimation(.easeInOut(duration: 0.5))` cross-fades to next screen

### AppStorage keys used
```swift
@AppStorage("hasSeenWelcomeScreen")  // Bool — drives welcome/creation flow
@AppStorage("appearanceMode")        // String — applied via preferredColorScheme at root
```

---

## 2. Onboarding

### What it does
A 4-page carousel shown the very first time the user completes profile creation and taps "Let's Go". After that, never shown again unless the user taps "Reset Onboarding" in Settings.

### Status
✅ Implemented

### Files
- `OnboardingView.swift`
- `OnboardingPageView.swift`

### How it works
`OnboardingView` owns a `currentPage: Int` state var. A `TabView` with `.tabViewStyle(.page)` renders the pages as a horizontal scroll carousel. There's a "Skip" button, "Next" button, and on the last page a "Get Started" button.

Tapping "Get Started" sets:
```swift
@AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = true
```

`ContentView` reads this key and shows `HomeView` if true.

### Each page content
Each `OnboardingPageView` receives: `imageName`, `title`, `subtitle`. The image is an SF Symbol displayed large, the title is bold, the subtitle is secondary-colored.

---

## 3. Profile System (Netflix-style)

### What it does
Lets the user create up to 5 named profiles, each with their own SF Symbol avatar, accent color, and completely isolated trip history. On every launch, the user picks which profile to use — just like Netflix's "Who's watching?" screen.

### Status
✅ Implemented

### Files
- `UserProfile.swift` — data model
- `ProfileService.swift` — singleton service
- `ProfileCreationView.swift` — first-launch setup screen
- `ProfileSelectionView.swift` — every-launch grid picker
- `ProfileSwitcherView.swift` — in-app manage sheet (from Settings)
- `AddProfileSheet.swift` — inline in `ProfileSelectionView.swift`

### Data model
```swift
struct UserProfile: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var avatarSymbol: String   // SF Symbol, e.g. "person.fill", "star.fill"
    var avatarColor: String    // Hex string, e.g. "#3B82F6"
}
```

8 avatar symbols available: `person.fill`, `star.fill`, `heart.fill`, `bolt.fill`, `leaf.fill`, `flame.fill`, `moon.fill`, `airplane`

8 accent colors: blue, indigo, purple, pink, orange, teal, red, green

### ProfileService
`@Observable @MainActor` singleton. Stores profiles in UserDefaults as JSON:
```
Key: "user_profiles_v1"      → [UserProfile] encoded as Data
Key: "active_profile_id_v1"  → UUID string
```

Key methods:
- `createProfile(name:avatarSymbol:avatarColor:)` — appends, activates, persists
- `switchTo(_ profile:)` — updates `activeProfile`, saves active ID
- `rename(_ profile:to:)` — updates in array + persists
- `delete(_ profile:)` — removes history file, removes from array, cannot delete last
- `activeHistoryFileURL()` — returns `Documents/history_<id>.json` for the active profile

### Profile isolation
Each profile's trip data is in a separate JSON file: `history_<profileID>.json`. When `ProfileService.switchTo()` is called, `TripHistoryService` automatically reads from the new profile's file because it calls `ProfileService.shared.activeHistoryFileURL()` dynamically.

### ProfileCreationView flow
1. Name text field (auto-focuses on appear)
2. Horizontal scroll of 8 avatar symbols — tappable circles
3. Row of 8 color dots — tappable with scale animation
4. Live avatar preview circle (updates immediately as you pick)
5. "Let's Go →" button — disabled (gray) until name is non-empty
6. On tap: `profileService.createProfile(...)` → `navigateToHome = true` → cross-fade to `HomeView`

### ProfileSelectionView (Netflix grid)
- `LazyVGrid` with 2 columns
- Each `ProfileGridCell` shows the avatar circle + name
- Tap → `profileService.switchTo(profile)` → `navigateToHome = true`
- `AddProfileCell` at end (hidden when 5 profiles reached)
- "Manage Profiles" button → `ProfileSwitcherView` sheet

---

## 4. Home Dashboard

### What it does
The main screen after login. Shows a personalised greeting, today's active plan (if any), and all plans sorted newest-first.

### Status
✅ Implemented

### Files
- `HomeView.swift`
- `HomeViewModel.swift`

### Greeting logic
```swift
var greeting: String {
    let hour = Calendar.current.component(.hour, from: .now)
    switch hour {
    case 5..<12:  return "Good morning"
    case 12..<17: return "Good afternoon"
    case 17..<21: return "Good evening"
    default:      return "Good night"
    }
}
```

### Today's Focus
`var todaysItem: PlanItem? { items.first { $0.status == .active } }`

`PlanStatus` is auto-derived from the plan's date — no stored value:
- `.active` if date is today
- `.upcoming` if date is in the future
- `.completed` if date is in the past

### Plan Cards
Two card types based on `PlanItem` enum:
- `DayPlanCard` — shows stop count, planned duration, travel mode, "View Route" button
- `TripCard` — shows emoji, days, total stops, travel mode, "View Trip" button, colored accent

Both use `.regularMaterial` background, `RoundedRectangle(cornerRadius: 18)`, box shadow.

### FAB (Floating Action Button)
```
+ (main button, blue circle, bottom-right)
  → tap → isFABMenuOpen = true (spring animation)
  → two options slide up:
    • "Plan a Day" (calendar.badge.plus, blue)
    • "Plan a Trip" (map.fill, indigo)
  → tap option → show builder sheet
```
`toggleFAB()` uses `withAnimation(.spring(response: 0.3, dampingFraction: 0.7))`.

### Empty State
When no plans exist: large `map.fill` SF Symbol on a light blue circle, "No Plans Yet" heading, "+ Create Your First Plan" blue CTA button (opens DayPlan builder directly).

### Swipe Actions
`.swipeActions(edge: .trailing, allowsFullSwipe: false)` on each card:
- Red "Delete" → sets `viewModel.itemPendingDelete` → confirmation alert
- Blue "Edit" → calls `viewModel.startEditing(item)` → sets `editingDayPlan` or `editingTrip`

### Edit flow
`HomeViewModel` has:
```swift
var editingDayPlan: DayPlan? = nil
var editingTrip: Trip? = nil
```
`.sheet(item: $viewModel.editingDayPlan)` and `.sheet(item: $viewModel.editingTrip)` — SwiftUI `Identifiable`-driven sheets. The builder opens pre-filled with existing data.

---

## 5. Day Plan Builder

### What it does
A sheet for creating or editing a single-day plan. User searches for places, adds stops, sets durations, picks travel mode, and confirms.

### Status
✅ Implemented

### Files
- `DayPlanBuilderView.swift`
- `DayPlanBuilderViewModel.swift`

### Two modes
- **Create mode**: `DayPlanBuilderView(onConfirmed:)` — blank form
- **Edit mode**: `DayPlanBuilderView(editing: plan, onConfirmed:)` — pre-filled

Edit mode works because `DayPlanBuilderViewModel(editing:)` pre-fills all fields and stores `existingID`. `save()` passes the same ID back so `TripHistoryService.save()` upserts (replaces) the record rather than creating a new one.

### Search
`PlaceSearchService` wraps `MKLocalSearch`. It debounces input using a simple approach — a `Task` with `Task.sleep`. Each keystroke cancels the previous search task.

```swift
func search(query: String) {
    searchTask?.cancel()
    searchTask = Task {
        try? await Task.sleep(nanoseconds: 400_000_000)  // 400ms debounce
        // run MKLocalSearch
    }
}
```

Results are `[MKMapItem]`. The address is extracted from `mapItem.addressRepresentations?.fullAddress(...)` (iOS 18+) with a fallback to `placemark.thoroughfare + locality`.

### Stop list
- `ForEach` over `viewModel.stops` — `StopRow` for each
- Each `StopRow` shows number badge, stop name, address, a tappable duration badge
- Duration badge → `StopDurationPickerSheet` (shared component)
- `onRemove`: `viewModel.removeStop(stop)`
- `onDurationChanged`: `viewModel.updateDuration(for:minutes:)` → `max(5, minutes)`

### Map preview
When stops exist, a `Map` view with `Annotation` pins shows below the search bar. Camera updates whenever a stop is added.

### Confirm
`viewModel.canConfirm` = `!stops.isEmpty`. On confirm: `DayPlan` constructed → `onConfirmed(plan)` closure called → `HomeViewModel.saveDayPlan()`.

---

## 6. Trip Builder (Multi-Day)

### What it does
A 2-step sheet for creating/editing a multi-day trip. Step 1: metadata (name, emoji, color, dates, days). Step 2: add stops per day.

### Status
✅ Implemented

### Files
- `TripBuilderView.swift`
- `TripBuilderViewModel.swift`

### 2-step flow
```
Step 0: TripMetadataForm
  - Trip name (text field)
  - Emoji picker (horizontal scroll, 12 options)
  - Color picker (8 color dots)
  - Start date (DatePicker)
  - Number of days (Stepper, 1–7)
  - Travel mode (Picker)
  → "Next: Add Stops" button

Step 1: Stops per day
  - Day tab bar (Picker segmented, only shown if >1 day)
  - Search bar (same PlaceSearchService)
  - Map + stop list per selected day
  → "Create Trip" / "Save Changes" button
```

### Per-day stops
`dayStops: [[Stop]]` — an array of arrays. `selectedDayIndex` tracks which day's stops are shown. The `stops` computed property is a get/set proxy into `dayStops[selectedDayIndex]`.

`numberOfDays` has a `didSet` that grows/shrinks `dayStops` to match.

### `canConfirm`
```swift
var canConfirm: Bool { dayStops.allSatisfy { !$0.isEmpty } }
```
All days must have at least one stop.

### Edit mode
`init(editing: Trip)` pre-fills all fields. Crucially, `existingTripID` and `existingDayIDs` are stored. `confirm()` reuses them:
```swift
let dayID = i < existingDayIDs.count ? existingDayIDs[i] : UUID()
let trip = Trip(id: existingTripID ?? UUID(), ...)
```
This makes `TripHistoryService.save()` treat it as an update, not a new record.

---

## 7. Route Optimizer

### What it does
Shows the optimised route for a Day Plan on a full-screen map. Calculates the most efficient stop order, fetches real road legs via MKDirections, draws a polyline, shows stats.

### Status
✅ Implemented

### Files
- `RouteOptimizerView.swift`
- `RouteOptimizerViewModel.swift`
- `RouteService.swift`
- `MinHeap.swift`

### RouteState enum
```swift
enum RouteState {
    case idle
    case loading
    case success(ComputedRoute)
    case failure(String)
}
```
The view switches on this to render: nothing / spinner card / success card / error card.

### ComputedRoute
```swift
struct ComputedRoute {
    let orderedStops: [Stop]      // stops in optimised order
    let legs: [RouteLeg]          // one leg per consecutive pair
    let totalDistanceMeters: Double
    let totalTravelTimeSeconds: Double
}
```

### RouteLeg
```swift
struct RouteLeg {
    let from: Stop
    let to: Stop
    let distanceMeters: Double
    let travelTimeSeconds: Double
    let polyline: MKPolyline      // drawn on map
}
```

### Optimisation algorithm (Nearest Neighbour)
```
1. Start from origin (GPS location if available, else stops[0])
2. Build MinHeap of all unvisited stops keyed by Haversine distance
3. extractMin() = nearest stop → add to ordered list
4. Repeat from that stop until all stops visited
```

### Haversine formula
Calculates straight-line distance between two GPS coordinates on Earth's surface (accounts for Earth's curvature). Used for ordering decisions — actual road distance comes from MKDirections after ordering.

### MKDirections legs
After ordering, `buildRoute(orderedStops:)` calls `fetchLeg(from:to:)` for each consecutive pair. This makes a real `MKDirections.Request` and gets back distance, travel time, and the `MKPolyline` for that segment. These calls run sequentially (`for (from, to) in zip(...)`).

### Stop pins
- Green circle = first stop
- Red circle = last stop
- Blue circle = middle stops
- Numbers assigned by `enumerated()` — not stored in the model

---

## 8. Drag-to-Reorder Route

### What it does
Lets the user manually rearrange stops in the route by dragging, then recalculate with their custom order.

### Status
✅ Implemented

### Files
- `RouteOptimizerView.swift` — edit sheet UI
- `RouteOptimizerViewModel.swift` — edit state + recalculate logic

### Edit mode state
```swift
var isEditingRoute = false
var reorderedStops: [Stop] = []    // working copy during drag
var hasUserReordered = false       // true after first drag move
var showDiscardAlert = false
```

### Entering edit mode
Tap the "Edit" pencil capsule button on the success card:
```swift
func enterEditMode() {
    guard case .success(let route) = routeState else { return }
    reorderedStops = route.orderedStops   // copy current order
    hasUserReordered = false
    isEditingRoute = true
}
```

### Drag implementation
SwiftUI `List` with `.onMove` modifier + `.environment(\.editMode, .constant(.active))`:
```swift
List {
    ForEach(viewModel.reorderedStops, ...) { ... }
    .onMove { source, destination in
        viewModel.moveStop(from: source, to: destination)
    }
}
.environment(\.editMode, .constant(.active))
```
`.constant(.active)` forces the list into edit mode (shows drag handles) without needing a toolbar Edit button.

### Locked stops
First and last stops are visually locked (lock icon, grayed out). However SwiftUI's `.onMove` doesn't natively prevent specific rows from moving. The visual indicator communicates intent — a future improvement could add index guards in `moveStop()`.

### Recalculate
```swift
func recalculateWithUserOrder() async {
    // Calls RouteService.computeRoute(orderedStops: reorderedStops, ...)
    // Skips nearest-neighbour — uses stops exactly as arranged
    // Updates routeState, trip, dismisses edit mode
    // Shows success toast for 2.5s
}
```

### Cancel with discard confirmation
```swift
func requestCancelEdit() {
    if hasUserReordered {
        showDiscardAlert = true   // → "Discard Changes?" alert
    } else {
        isEditingRoute = false    // no changes → exit immediately
    }
}
```

---

## 9. GPS Route Optimisation

### What it does
Uses the user's current GPS location as the invisible starting point (Stop #0) so that Stop #1 is always the stop closest to where they physically are.

### Status
✅ Implemented

### Files
- `RouteOptimizerViewModel.swift` — GPS integration
- `RouteService.swift` — `startingCoordinate` param
- `RouteOptimizerView.swift` — GPS unavailable banner

### How it works
```swift
// In calculateRoute():
let gpsCoord = locationService.isAuthorized
    ? locationService.currentLocation?.coordinate
    : nil
showGPSUnavailableBanner = (gpsCoord == nil)

let route = try await routeService.computeRoute(
    for: dayPlan,
    startingCoordinate: gpsCoord    // nil = fallback to legacy behaviour
)
```

In `RouteService.nearestNeighborOrder(stops:startingCoordinate:)`:
- If `startingCoordinate != nil`: use it as `currentCoord` for the first MinHeap pick; all stops remain as candidates
- If `nil`: pop `stops[0]`, add it to ordered, use its coordinate as the seed (legacy)

### GPS permission
`locationService.requestPermission()` is called once at the start of `calculateRoute()`. iOS shows the system dialog at most once — after that, it returns the cached answer instantly. Auto-starts tracking after permission is granted via `locationManagerDidChangeAuthorization`.

### GPS unavailable banner
```
📍 Using first added stop as start (location access unavailable)
```
Shown as a capsule at the top of the map when `showGPSUnavailableBanner == true`. Appears when: GPS denied, GPS not yet fixed, or permission not determined.

### Re-optimise on stop reached (FR4)
```swift
func onStopReached(_ stop: Stop) {
    visitedStopIDs.insert(stop.id)
    let remaining = currentRoute.orderedStops.filter { !visitedStopIDs.contains($0.id) }
    // Re-run optimisation from current GPS position
    let newRoute = try await routeService.computeRoute(
        remainingStops: remaining,
        from: currentGPS,
        travelMode: dayPlan.travelMode
    )
    // Update route, show "Route updated — X stops remaining" toast
}
```

---

## 10. MinHeap Algorithm

### What it does
A generic binary min-heap data structure used to find the nearest unvisited stop efficiently during route optimisation.

### Status
✅ Implemented

### File
- `MinHeap.swift`

### Why it was added
The original nearest-neighbour used `Array.min(by:)` inside the main loop — O(n) per step, O(n²) total. For 20 stops that's 400 comparisons. The MinHeap reduces this to O(n log n) — about 86 comparisons for 20 stops.

### Structure
```swift
struct MinHeap<T> {
    private var heap: [T] = []
    private let comparator: (T, T) -> Bool
    
    mutating func insert(_ element: T)      // O(log n) — append + siftUp
    mutating func extractMin() -> T?         // O(log n) — swap root↔last + siftDown
    var isEmpty: Bool
    var count: Int
    var min: T?                              // O(1) peek
}
```

### Heap invariant
`heap[i] ≤ heap[2i+1]` and `heap[i] ≤ heap[2i+2]`

Parent index: `(child - 1) / 2`
Left child: `2 * parent + 1`
Right child: `2 * parent + 2`

### siftUp (used after insert)
Start at the inserted index, compare with parent, swap if child < parent, repeat upward.

### siftDown (used after extractMin)
Start at root, compare with both children, swap with smaller child if parent > child, repeat downward.

### Usage in RouteService
```swift
var heap = MinHeap<(distance: Double, stop: Stop)> { $0.distance < $1.distance }
for stop in unvisited {
    heap.insert((haversine(from: currentCoord, to: stop.coordinate), stop))
}
let nearest = heap.extractMin()!
```

---

## 11. Day Itinerary

### What it does
A vertical timeline view showing every stop with exact arrival times, departure times, time spent, and travel time between stops. Everything cascades — change one stop's duration and all subsequent arrival times update instantly.

### Status
✅ Implemented

### Files
- `ItineraryView.swift`
- `ItineraryViewModel.swift`

### ItineraryEntry
The ViewModel builds an array of `ItineraryEntry` objects:
```swift
struct ItineraryEntry {
    let stop: Stop
    let arrivalTime: Date
    let departureTime: Date
    let legToNext: RouteLeg?           // nil for last stop
    var minuteOverride: Int? = nil     // user-edited duration
    
    var effectiveMinutes: Int {
        Int(departureTime.timeIntervalSince(arrivalTime) / 60)
    }
}
```

`effectiveMinutes` derives duration from the departure/arrival gap — it reflects the live override, not the stale `stop.minutesToSpend`.

### Cascade calculation
`ItineraryViewModel.buildEntries()` runs through stops in order:
```
arrivalTime[0] = startTime
departureTime[0] = arrivalTime[0] + minutesToSpend[0]
arrivalTime[1] = departureTime[0] + travelTimeSeconds[leg0]
departureTime[1] = arrivalTime[1] + minutesToSpend[1]
... and so on
```

When the user changes a duration, `updateMinutesToSpend(for:minutes:)` rebuilds the entire entries array from scratch — all times downstream recalculate automatically.

### Timeline layout
Each row: `HStack` with a left "spine" column (60px wide) and a right card column.
- Spine: time label + coloured dot + vertical connecting line
- Card: stop name, address, time range, duration badge

This is not a `List` — it's `ForEach` inside a `ScrollView`. This avoids List's separators and padding which would break the continuous vertical line effect.

---

## 12. Stop Duration Editor

### What it does
Tappable "X min" badge on each stop in both the builders and the itinerary. Opens a half-height sheet with a slider (5–240 min) and quick-pick presets.

### Status
✅ Implemented

### File
- `DayPlanBuilderView.swift` — `StopDurationPickerSheet` (shared component)

### Shared component
`StopDurationPickerSheet` is a `public struct` (not private) in `DayPlanBuilderView.swift` so both the builder views and `ItineraryView` can use it without duplication.

```swift
struct StopDurationPickerSheet: View {
    let stopName: String
    let currentMinutes: Int
    let onConfirm: (Int) -> Void
    
    @State private var minutes: Int  // bound to slider
    // Quick presets: [15, 30, 45, 60, 90]
    // Slider range: 5...240, step 5
    // .presentationDetents([.medium]) — half-height sheet
}
```

### Where it's wired
- `DayPlanBuilderView.StopRow.onDurationChanged` → `DayPlanBuilderViewModel.updateDuration(for:minutes:)`
- `TripBuilderView.StopRow.onDurationChanged` → `TripBuilderViewModel.updateDuration(for:minutes:)`
- `ItineraryView.TimelineRow.onMinutesChanged` → `ItineraryViewModel.updateMinutesToSpend(for:minutes:)`

---

## 13. Navigation (Stop-by-Step)

### What it does
Guides the user through their planned stops one by one. Shows a progress bar, current stop info, "Navigate" (opens Apple Maps) and "Arrived" buttons, plus expandable step-by-step directions.

### Status
✅ Implemented

### Files
- `NavigationView.swift`
- `NavigationViewModel.swift`
- `NavigationService.swift`

### Stop progression
`currentStopIndex: Int` advances when "Arrived" is tapped. The view recomputes `currentStop`, `completedStops`, `remainingStops` from this single index.

### Apple Maps launch
`NavigationService.openInAppleMaps(to:mode:)` constructs an `MKMapItem` and calls `openInMaps(launchOptions:)` with `MKLaunchOptionsDirectionsModeKey` — opens Apple Maps pre-loaded with the destination and travel mode.

### Step-by-step directions
`NavigationService.fetchDirectionSteps(from:to:mode:)` calls `MKDirections` and extracts `route.steps` — each step has `notice` (the instruction) and `distance`. These are displayed in a collapsible `DisclosureGroup`.

### Trip complete
When `currentStopIndex >= stops.count`, a "Trip Complete!" celebration screen is shown.

---

## 14. Live GPS Navigation

### What it does
Real-time GPS tracking during a trip. Live route line from current position to next stop, auto ETA recalculation, auto-arrival detection at 50m.

### Status
✅ Implemented

### Files
- `LiveNavigationView.swift`
- `LiveNavigationViewModel.swift`
- `LocationService.swift`

### GPS observation pattern
`LiveNavigationViewModel` uses `withObservationTracking` — the modern @Observable equivalent of Combine's `sink`:

```swift
// Runs in a loop — whenever locationService.currentLocation changes,
// the onChange callback fires, continuation resumes, next location processed
withObservationTracking {
    _ = self.locationService.currentLocation   // "subscribe" to this property
} onChange: {
    continuation.resume()
}
```

### On each GPS update
1. **Camera**: `MapCamera(centerCoordinate:distance:heading:pitch:)` — 3D tilted view at 800m, follows device heading
2. **Auto-arrive**: `location.distance(from: stopLocation) < 50` → `showingArrivalBanner = true`
3. **Route recalc**: if moved 50m+ from `lastRouteCalcLocation` → new `MKDirections` call from current position to next stop → updates `livePolyline` + `etaSeconds`

### Why 50m threshold for recalculation
Without it, every single GPS update (every 10m per `distanceFilter`) would trigger an MKDirections request. 50m threshold prevents hammering the API and keeps ETA stable enough to be useful.

### Battery
`locationService.stopTracking()` is called in `stopLiveTracking()` which is called when the view disappears. GPS runs only while the Live Navigation screen is visible.

---

## 15. Trip History

### What it does
Shows all saved plans across all time, grouped into "Today", "This Week", and "Earlier" sections. Accessible from the clock icon in the Home toolbar.

### Status
✅ Implemented

### Files
- `TripHistoryView.swift`
- `TripHistoryViewModel.swift`
- `TripHistoryService.swift`

### Grouping logic
```swift
var grouped: [(title: String, items: [PlanItem])] {
    let today = Calendar.current.startOfDay(for: .now)
    let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: today)!
    // Group items into Today / This Week / Earlier buckets
}
```

### TripHistoryService
`actor TripHistoryService` — thread-safe JSON persistence.

- **File location**: `ProfileService.shared.activeHistoryFileURL()` → `Documents/history_<profileID>.json`
- `save(_ item: PlanItem)` — loads existing array, replaces if `id` matches (upsert), appends if new, writes back with `.atomic`
- `loadAll()` → `[PlanItem]` sorted newest-first
- `delete(id:)` → removes from array, writes back

---

## 16. Plan Reminder Notifications

### What it does
Schedules two local notifications for each plan: one at 7pm the evening before, one at 8am on the morning of the plan.

### Status
✅ Implemented

### File
- `NotificationService.swift`

### Two notifications per plan
```
Plan ID + "_evening" → UNCalendarNotificationTrigger at 7pm day before
Plan ID + "_morning" → UNCalendarNotificationTrigger at 8am on plan date
```

Both use `repeats: false`. Calling `scheduleReminder` again (when editing) first removes the old requests by identifier, so there's never a duplicate.

### Permission
`requestPermission()` calls `center.requestAuthorization(options: [.alert, .sound, .badge])`. iOS only shows the system dialog once — subsequent calls return the cached answer.

`isPermissionGranted()` checks `center.notificationSettings().authorizationStatus == .authorized`.

### Wired into HomeViewModel
```swift
func saveDayPlan(_ plan: DayPlan) {
    TripHistoryService.shared.save(item)
    Task { await NotificationService.shared.scheduleReminder(for: item) }
}
func delete(_ item: PlanItem) {
    NotificationService.shared.cancelReminder(for: item.id)
    TripHistoryService.shared.delete(id: item.id)
}
```

### Settings toggle
A toggle in Settings → Notifications section controls `@AppStorage("notificationsEnabled")`. If permission was denied, an "Enable in Settings" button deep-links to the iOS Settings app using `UIApplication.openSettingsURLString`.

---

## 17. Settings & Appearance

### What it does
User preferences stored in UserDefaults via `@AppStorage`. No ViewModel needed — `@AppStorage` properties re-render any view that reads them.

### Status
✅ Implemented

### File
- `SettingsView.swift`

### Sections
1. **Profile** — avatar + name card, taps → `ProfileSwitcherView` sheet
2. **Trip Defaults** — `Picker` with `.segmented` style for travel mode
3. **Notifications** — toggle, "Enable in Settings" button if denied
4. **Appearance** — inline `Picker` for System/Light/Dark
5. **About** — app version from `Bundle.main.infoDictionary`
6. **Danger Zone** — "Reset Onboarding" button

### Live theme switching
`SettingsView` applies `.preferredColorScheme(resolvedColorScheme)` to its own `NavigationStack`. This means the sheet itself updates instantly when you pick a new appearance. The root `SplashScreenView` also reads the same key and applies it to the whole app.

### Why no ViewModel?
All three settings are simple key-value pairs. `@AppStorage` reads/writes UserDefaults directly. Any view in the app that reads the same key re-renders automatically — no ViewModel, no service, no JSON needed.

---

## 18. Multi-User Profiles (Data Layer)

### What it does
Provides complete data isolation between users. Each profile's trips are stored in a separate file, so switching profiles instantly shows that person's plans.

### Status
✅ Implemented

### Files
- `ProfileService.swift`
- `TripHistoryService.swift` (reads active profile URL)

### Isolation mechanism
```
Profile A (UUID: abc-123)  →  Documents/history_abc-123.json
Profile B (UUID: def-456)  →  Documents/history_def-456.json
```

When `ProfileService.switchTo(profileB)` is called:
1. `activeProfile = profileB`
2. `UserDefaults["active_profile_id_v1"] = profileB.id.uuidString`
3. Next `TripHistoryService.loadAll()` call reads `activeHistoryFileURL()` which now returns `history_def-456.json`
4. `HomeViewModel.reload()` is triggered via `.onChange(of: profileService.activeProfile?.id)` in `HomeView`

### Max profiles enforcement
```swift
static let maxProfiles = 5
func createProfile(...) -> Bool {
    guard profiles.count < ProfileService.maxProfiles else { return false }
    ...
}
```

### Cannot delete last profile
```swift
func delete(_ profile: UserProfile) {
    guard profiles.count > 1 else { return }
    ...
}
```

---

## 19. Persistence Layer

### What it does
All trips are saved automatically to JSON files on the device. Nothing is ever lost between app restarts.

### Status
✅ Implemented

### File
- `TripHistoryService.swift`

### File format
`[PlanItem]` encoded as JSON. `PlanItem` is an enum with associated values — requires custom `Codable` implementation using a `type` + `payload` pattern:

```swift
// Encoding
switch self {
case .singleDay(let d):
    try c.encode(ItemType.singleDay, forKey: .type)
    try c.encode(d, forKey: .payload)
}

// Decoding
switch type {
case .singleDay:
    self = .singleDay(try c.decode(DayPlan.self, forKey: .payload))
}
```

### Atomic writes
```swift
try data.write(to: fileURL, options: .atomic)
```
`.atomic` writes to a temp file first, then renames it. This means the file is never in a half-written state if the app crashes mid-write.

### Stop.isVisited excluded from Codable
`Stop` has a `CodingKeys` enum that lists only the persistent fields:
```swift
enum CodingKeys: String, CodingKey {
    case id, name, address, latitude, longitude, minutesToSpend
    // isVisited deliberately omitted — it's a transient runtime flag
}
```
This means `isVisited` is never written to disk, and loading old JSON (which has no `isVisited` key) never fails — it just defaults to `false`.

---

## 20. Edit & Delete Plans

### What it does
Users can edit any existing plan (re-open the builder pre-filled with existing data) or delete it, from swipe actions or the context menu.

### Status
✅ Implemented

### Files
- `HomeView.swift` — swipe actions, sheets, alert
- `HomeViewModel.swift` — state vars, intents

### Swipe actions
```swift
.swipeActions(edge: .trailing, allowsFullSwipe: false) {
    Button(role: .destructive) { viewModel.itemPendingDelete = item } label: {
        Label("Delete", systemImage: "trash")
    }
    Button { viewModel.startEditing(item) } label: {
        Label("Edit", systemImage: "pencil")
    }.tint(.blue)
}
```

`allowsFullSwipe: false` prevents accidental deletion — user must tap the button.

### Edit sheet pattern
`HomeViewModel` has optional state vars:
```swift
var editingDayPlan: DayPlan? = nil
var editingTrip: Trip? = nil
```

SwiftUI `.sheet(item:)` — when the value is non-nil, sheet appears. When sheet is dismissed, the value is set back to nil:

```swift
.sheet(item: $viewModel.editingDayPlan) { plan in
    DayPlanBuilderView(editing: plan) { updated in
        viewModel.saveDayPlan(updated)
    }
}
```

### Delete confirmation
Uses a `Binding<Bool>` derived from `itemPendingDelete != nil`:
```swift
.alert("Delete Plan?", isPresented: Binding(
    get: { viewModel.itemPendingDelete != nil },
    set: { if !$0 { viewModel.itemPendingDelete = nil } }
)) { ... }
```

### Upsert on save
`TripHistoryService.save()` loads the current array, searches by `id`, replaces if found, appends if not. This is why edit mode works — the same ID comes back from the builder, so the old record is replaced.

---

*Last updated: July 2026 — covers all features through GPS route optimisation branch.*
