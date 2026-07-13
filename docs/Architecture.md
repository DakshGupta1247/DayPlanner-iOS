# PlanDay — Architecture

## Pattern: MVVM

The app follows MVVM (Model-View-ViewModel). Here's what each layer does:

| Layer | Responsibility | Example files |
|---|---|---|
| **Model** | Pure data, no UI | `Trip.swift`, `DayPlan.swift`, `UserProfile.swift` |
| **ViewModel** | Holds screen state, talks to Services | `HomeViewModel.swift`, `RouteOptimizerViewModel.swift` |
| **View** | Displays data from ViewModel, no logic | `HomeView.swift`, `RouteOptimizerView.swift` |
| **Service** | Does the heavy work (network, disk, GPS) | `RouteService.swift`, `LocationService.swift` |

**Rule:** Views never call Services directly. They always go through a ViewModel.

---

## Full File Map

```
Models/
  Trip.swift                    — Stop, Trip, TravelMode structs
  DayPlan.swift                 — DayPlan struct, PlanStatus enum
  PlanItem.swift                — Union enum (singleDay | multiDayTrip), Codable
  UserProfile.swift             — UserProfile, ProfileColor, ProfileAvatar

Services/
  RouteService.swift            — MKDirections + MinHeap nearest-neighbour routing
  MinHeap.swift                 — Generic binary min-heap (O(log n) insert/extract)
  PlaceSearchService.swift      — MKLocalSearch with debounce
  NavigationService.swift       — Apple Maps URL launcher + MKDirections steps
  TripHistoryService.swift      — JSON read/write to Documents folder (per-profile)
  LocationProviding.swift       — Protocol abstracting GPS delivery (real vs. GPX replay)
  LocationService.swift         — CLLocationManager wrapper; conforms to LocationProviding
  LocationIntegrityGate.swift   — actor; validates GPS fixes (accuracy, staleness, teleport)
  ETAEngine.swift               — EMA speed smoother, ETAResult, ClosingTimeVerdict
  GPXParser.swift               — XMLParser-based .gpx file decoder → [CLLocation]
  GPXReplayProvider.swift       — Replays a .gpx file as live GPS (DEBUG builds, 6× speed)
  StopsLoader.swift             — Decodes Resources/stops.json into [Stop] with openUntil dates
  ProfileService.swift          — Profile CRUD, active profile, per-profile isolation
  NotificationService.swift     — UNUserNotificationCenter, evening + morning reminders

AppEnvironment.swift            — #if DEBUG → GPXReplayProvider, else → LocationService

Resources/
  stops.json                    — 6 bundled Delhi landmarks with openUntil "HH:mm" fields
  demo-route.gpx                — 40-point GPX route: CP → India Gate → Humayun's Tomb → Lotus Temple → Qutub Minar → Red Fort

ViewModels/
  HomeViewModel.swift           — Plans list, FAB state, edit/delete, notification scheduling
  DayPlanBuilderViewModel.swift — Stop list, search, duration editing (single day)
  TripBuilderViewModel.swift    — Multi-day stops, day tabs, edit mode
  RouteOptimizerViewModel.swift — RouteState, GPS integration, edit mode, re-optimise
  ItineraryViewModel.swift      — Cascading arrival times, start time, minute overrides
  NavigationViewModel.swift     — Stop progression, step fetching from MKDirections
  LiveNavigationViewModel.swift — Real-time GPS, ETAEngine, auto-arrival at 100m, monotonic crossing, routeCalcInFlight guard, destination toast, progress counters
  TripHistoryViewModel.swift    — Grouped history list, delete
  (Settings has no ViewModel — uses @AppStorage directly)

Features/
  Splash/         SplashScreenView (root), WelcomeScreenView
  Onboarding/     OnboardingView, OnboardingPageView
  Home/           HomeView (greeting, cards, FAB, swipe actions)
  Profiles/       ProfileCreationView, ProfileSelectionView, ProfileSwitcherView
  DayPlanBuilder/ DayPlanBuilderView, StopRow, StopDurationPickerSheet
  TripBuilder/    TripBuilderView, TripMetadataForm, PlaceSearchResultRow
  TripDetail/     TripDetailView
  RouteOptimizer/ RouteOptimizerView (map, bottom card, edit sheet, toasts)
  Itinerary/      ItineraryView, TimelineRow, StopCard, StartTimePicker
  Navigation/     NavigationView, LiveNavigationView, DayCompleteView
  TripHistory/    TripHistoryView
  Settings/       SettingsView

Components/
  TripSummaryCard.swift         — Reused on Home and TripDetailView
  Color+Hex.swift               — Color.hex() static func (avoids iOS 26 conflict)
```

---

## Key Swift / SwiftUI Patterns

### @Observable (iOS 17+)
Modern replacement for `ObservableObject + @Published`. Any property read inside a SwiftUI `body` is automatically tracked.

```swift
@Observable @MainActor
final class HomeViewModel {
    var items: [PlanItem] = []   // SwiftUI auto-tracks reads of this
}
```

### @AppStorage
Direct wrapper around UserDefaults. Used for settings, flags, and profiles.

```swift
@AppStorage("appearanceMode") private var appearanceMode = "system"
```

### actor (thread safety)
`RouteService` and `NavigationService` are Swift `actor`s — Swift guarantees serial access, preventing data races during parallel MKDirections calls.

### async/await
All async work (MKDirections, MKLocalSearch, CLLocationManager) uses Swift async/await. No Combine anywhere.

### .task modifier
Preferred over `.onAppear + Task {}`. Automatically cancels async work if the view disappears.

### AsyncStream single-consumer pattern
`LiveNavigationViewModel` uses a single `for await location in locationService.trustedLocationStream` loop for all location-driven work. `AsyncStream` only supports one active consumer — a second `Task` consuming the same stream starves the first. All camera updates, ETA refreshes, and arrival detection run in this one loop. Route recalculation is spawned as a separate fire-and-forget task so the loop is never blocked by network calls.

---

## Data Flow: Route Calculation

```
User taps "Create Trip" in TripBuilderView
  → TripBuilderViewModel.confirm() calls onConfirmed closure
  → HomeViewModel.saveTrip() → TripHistoryService.save() → reload()
  → NotificationService.scheduleReminder() schedules evening + morning alerts
  → HomeView shows TripCard

User taps "View Route"
  → RouteOptimizerView appears
  → .task calls viewModel.calculateRoute()
  → LocationService.requestPermission() (if not determined)
  → LocationService.startTracking() → reads currentLocation?.coordinate
  → RouteService.computeRoute(for: dayPlan, startingCoordinate: gpsCoord)
      → nearestNeighborOrder(stops:startingCoordinate:)
          → if gpsCoord != nil: use GPS as invisible origin for first pick
          → MinHeap built per step, extractMin() = nearest stop — O(n log n)
          → otherwise: first user-added stop = origin (fallback)
      → buildRoute(orderedStops:) → fetchLeg() per consecutive pair
          → MKDirections.Request → .calculate() → RouteLeg (distance, time, polyline)
  → ComputedRoute returned → routeState = .success(route)
  → SwiftUI re-renders map + bottom card with numbered pins + polyline
```

## Data Flow: Live Navigation

```
LocationProviding (protocol)
  ├── DEBUG build → GPXReplayProvider: replays demo-route.gpx at 6× speed (~5s/fix)
  └── Release build → LocationService: CLLocationManager → LocationIntegrityGate.validate()
        ├── .trusted / .degraded → emitted on trustedLocationStream
        └── .untrusted → dropped silently

trustedLocationStream (AsyncStream<CLLocation>) — single consumer loop in LiveNavigationViewModel:
  → ETAEngine.update(newLocation:) — EMA speed smoothing (α=0.3)
  → refreshSpeedETA(from:) → ETAResult (durationSeconds, arrivalTime, distanceMeters)
  → handleLocationUpdate(location) [synchronous]:
      ├── MapCamera: tilted 3D, follows heading, 800m altitude
      ├── Check distance to currentStop < 100m
      │   AND stop.id not in crossedStopIDs (monotonic guard)
      │   → crossedStopIDs.insert(stop.id) + showingArrivalBanner = true
      └── if moved 150m+ from lastRouteCalcLocation AND !routeCalcInFlight:
          → spawn routeCalcTask (fire-and-forget, does NOT block the location loop)
          → routeCalcInFlight = true
          → MKDirections from current GPS → next stop
          → guard generation == routeCalcGeneration (discard if stop advanced)
          → livePolyline + etaSeconds updated
          → routeCalcInFlight = false

markCurrentStopArrived():
  → currentStopIndex += 1
  → routeCalcGeneration += 1  (invalidates any in-flight MKDirections response)
  → clears livePolyline, etaSeconds, etaResult, etaIsLoading
  → showDestinationToast() → "Next: <stop name>" pill, auto-dismisses 2.5s
  → checkIfDayComplete() → 0.8s delay → isDayComplete = true → DayCompleteView (fullScreenCover)

1s Timer:
  → refreshSpeedETA(from: currentLocation) → keeps arrival time display current
```

## Data Flow: Re-optimise After Stop Reached

```
onStopReached(stop) called
  → visitedStopIDs.insert(stop.id)
  → remaining = orderedStops.filter { !visitedStopIDs.contains($0.id) }
  → RouteService.computeRoute(remainingStops: remaining, from: gpsCoord)
      → nearestNeighborOrder with GPS as new origin
      → buildRoute for remaining legs only
  → routeState = .success(newRoute)
  → reoptimiseToastMessage = "Route updated — X stops remaining"
  → showReoptimiseToast = true (auto-dismiss 2.5s)
```

---

## Persistence

### Trip History
Each profile's trips stored at:
```
Documents/history_<profileID>.json
```
- `TripHistoryService.save(_:)` — upserts by ID (replaces existing, appends new)
- `TripHistoryService.loadAll()` — called in `HomeViewModel.init()`
- Writes use `.atomic` — file never half-written on crash

### Profiles
```
UserDefaults key: "user_profiles_v1"  → [UserProfile] (JSON)
UserDefaults key: "active_profile_id_v1" → UUID string
```

### Settings
```
UserDefaults keys (all via @AppStorage):
  "defaultTravelMode"       → String (TravelMode.rawValue)
  "appearanceMode"          → String ("system" | "light" | "dark")
  "notificationsEnabled"    → Bool
  "hasCompletedOnboarding"  → Bool
  "hasSeenWelcomeScreen"    → Bool
```

---

## MinHeap Algorithm

`MinHeap<T>` in `MinHeap.swift` is a generic binary min-heap (pure Swift struct).

**Why:** Nearest-neighbour was O(n²) using `Array.min(by:)` inside a loop. MinHeap reduces it to O(n log n).

**How it works:**
```
Insert:     append to array → siftUp   (O(log n))
ExtractMin: swap root↔last → removeLast → siftDown (O(log n))
Invariant:  heap[i] ≤ heap[2i+1] and heap[i] ≤ heap[2i+2]
```

**Usage in RouteService:**
```swift
// At each step, build heap of all unvisited stops keyed by Haversine distance
var heap = MinHeap<(distance: Double, stop: Stop)> { $0.distance < $1.distance }
for stop in unvisited { heap.insert((haversine(from: current, to: stop.coordinate), stop)) }
let nearest = heap.extractMin()!
```

---

## Branch Strategy

```
main          ← production-ready, merged via PR
  └── develop ← integration (all FRs merge here first)
        └── feature/xxx ← one branch per feature
```
