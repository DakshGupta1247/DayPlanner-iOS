# PlanDay — iOS Day Trip Planner

A smart personal day-trip planner built with SwiftUI and MapKit.

Plan a day visiting multiple places → get a GPS-aware optimised route → follow a live itinerary → navigate stop by stop.

---

## Demo Videos

| # | Video | Duration |
|---|---|---|
| 1 | [User Onboarding](https://github.com/DakshGupta1247/DayPlanner-iOS/releases/download/v1.0-demo/01-user-onboarding.mp4) | 1 min 7s |
| 2 | [GPX Live Navigation Demo](https://github.com/DakshGupta1247/DayPlanner-iOS/releases/download/v1.0-demo/02-gpx-live-demo.mp4) | 5 min 15s |
| 3 | [Day Plan Setup](https://github.com/DakshGupta1247/DayPlanner-iOS/releases/download/v1.0-demo/03-day-plan-setup.mp4) | 2 min 41s |

> Click each link to download and view. All videos recorded on iPad (1488×2266).

---

## Tech Stack

| Technology | Usage |
|---|---|
| **SwiftUI** | All UI, declarative layout, iOS 17+ |
| **MapKit + MKDirections** | Maps, routing, polylines, place search |
| **CoreLocation / CLLocationManager** | Real-time GPS tracking, permission handling |
| **Swift async/await** | All async calls — no Combine anywhere |
| **@Observable (iOS 17)** | ViewModels and Services use the new macro |
| **FileManager + JSON** | Per-profile trip persistence in Documents folder |
| **@AppStorage / UserDefaults** | Settings, onboarding flag, profiles list |
| **UserNotifications** | Local reminders (evening before + morning of each plan) |

## Features

### Core (FR1–FR9)

| # | Feature | Status | Description |
|---|---|---|---|
| FR1 | Onboarding | ✅ | 4-page carousel, shown once on first launch |
| FR2 | Home Dashboard | ✅ | Greeting, Today's Focus, All Plans list, animated FAB |
| FR3 | Day Plan Builder | ✅ | MKLocalSearch place search, stop list, map preview, duration picker |
| FR4 | Route Optimizer | ✅ | Nearest-neighbour + MKDirections polyline, GPS start point, drag-to-reorder |
| FR5 | Day Itinerary | ✅ | Cascading timeline with arrival times, editable stop durations |
| FR6 | Navigation | ✅ | Stop-by-stop guidance with Apple Maps launcher |
| FR7 | Trip History | ✅ | Auto-saved plans per profile, grouped history sheet |
| FR8 | Settings | ✅ | Transport mode, appearance (light/dark/system), notifications, profiles |
| FR9 | Live Navigation | ✅ | Real-time GPS, live polyline, ETA, auto-arrival detection, destination toast, trip complete screen |

### Upgrades & Improvements

| # | Upgrade | Status | Description |
|---|---|---|---|
| U1 | Smart Cards | ✅ | `DayPlan` + `Trip` models, Day/Trip cards, animated FAB with two options |
| U2 | Multi-User Profiles | ✅ | Up to 5 profiles, per-profile data isolation, SF Symbol avatars, accent colours |
| U3 | UI Polish + Branding | ✅ | App icon, "PlanDay" display name, Splash/Welcome screens, empty state CTA |
| U4 | Edit & Delete | ✅ | Swipe actions (Edit/Delete), pre-filled edit forms, delete confirmation |
| U5 | Splash + Welcome | ✅ | Dark navy splash with logo animation, staggered welcome screen |
| U6 | Stop Duration Editor | ✅ | Tappable duration badge, slider + quick presets (5–240 min) |
| U7 | Plan Reminders | ✅ | Evening before (7pm) + morning of (8am) local notifications |
| U8 | Drag-to-Reorder Route | ✅ | List drag handle reorder, Recalculate button, discard confirmation |
| U9 | GPS Route Start | ✅ | User's GPS location as invisible stop #0 for optimisation |
| U10 | MinHeap Optimiser | ✅ | O(n log n) nearest-neighbour via binary min-heap |
| U11 | Netflix Profiles | ✅ | Profile Creation on first launch, Profile Selection grid on every launch |
| U12 | Live Theme Switching | ✅ | Light/Dark/System applied instantly from Settings sheet |
| U13 | GPX Demo Replay | ✅ | `#if DEBUG` GPX replay provider, 6× speed, "Load Delhi Demo" one-tap button on Home |
| U14 | Live Navigation Polish | ✅ | Destination toast, progress bar labels, fixed polyline/ETA delivery, stale-response guard |

## Architecture

MVVM — each screen has its own `View` + `ViewModel`. Services are `@Observable` singletons.

```
DayPlanner/
├── Models/           # DayPlan, Trip, Stop, PlanItem, TravelMode, UserProfile
├── Services/         # RouteService, LocationService, TripHistoryService,
│                     # ProfileService, NotificationService, PlaceSearchService,
│                     # NavigationService, MinHeap,
│                     # GPXParser, GPXReplayProvider, LocationProviding,
│                     # LocationIntegrityGate, ETAEngine
├── ViewModels/       # One ViewModel per screen / builder
├── Features/
│   ├── Splash/       # SplashScreenView, WelcomeScreenView
│   ├── Onboarding/   # OnboardingView, OnboardingPageView
│   ├── Home/         # HomeView (+ #if DEBUG DemoPlanBanner)
│   ├── Profiles/     # ProfileCreationView, ProfileSelectionView, ProfileSwitcherView
│   ├── DayPlanBuilder/
│   ├── TripBuilder/
│   ├── TripDetail/
│   ├── RouteOptimizer/
│   ├── Itinerary/
│   ├── Navigation/   # NavigationView, LiveNavigationView, DayCompleteView
│   ├── TripHistory/
│   └── Settings/
├── Resources/        # stops.json, demo-route.gpx
└── Components/       # TripSummaryCard, Color+Hex extension
```

## Key Design Decisions

- **Per-profile persistence** — each profile has its own `history_<uuid>.json`; switching profiles auto-loads that profile's data
- **Upsert by ID** — `TripHistoryService.save()` replaces existing records by matching ID, so editing never creates duplicates
- **GPS as invisible stop #0** — when permission is granted, the user's current location is used as the origin for nearest-neighbour optimisation so Stop #1 is always the closest stop to where the user is
- **MinHeap for O(n log n) routing** — nearest-neighbour uses a binary min-heap instead of linear scan
- **`Color.hex()` static func** — avoids conflict with iOS 26's new `Color(hex: Int)` initialiser
- **No Combine** — all async work uses Swift's native `async/await`
- **`isVisited` excluded from Codable** — `Stop.isVisited` is a transient runtime flag; excluded via `CodingKeys` so existing saved JSON never breaks
- **`.preferredColorScheme` on root** — applied at `SplashScreenView` (the true app root) and on every sheet so theme changes apply instantly everywhere
- **`LocationProviding` protocol** — abstracts GPS so both `LocationService` (real GPS) and `GPXReplayProvider` (simulator replay) work identically with all ViewModels
- **`AppEnvironment.locationProvider`** — single `#if DEBUG` switch; simulator always gets `GPXReplayProvider`, device always gets `LocationService`
- **Single `AsyncStream` consumer** — `LiveNavigationViewModel` uses one `for await` loop for all location events; dual consumers caused stream starvation and missed arrival detections
- **`routeCalcInFlight` flag** — prevents `MKDirections.calculate()` from being cancelled mid-flight on every GPS tick; only one route request runs at a time

## Running the App

1. Open `DayPlanner/DayPlanner.xcodeproj` in Xcode 15+
2. Select a Simulator (iPhone 16 Pro recommended) or your iPhone
3. Press `Cmd+R`

> **GPS Testing in Simulator:** Debug → Simulate Location → pick a city, or Features → Location → Custom Location in the simulator window.

> **Live Navigation (FR9):** Full GPS tracking works best on a real device.

## How to Run the GPX Demo

> GPX replay works on both Simulator and real device in DEBUG builds (run from Xcode). On a Release build, live GPS is used automatically.

### Steps

1. Build and run on iPhone/iPad Simulator (or real device via Xcode)

2. On the Home Screen, tap the blue **"Load Delhi Demo Plan"** banner
   → 6 Delhi landmarks load instantly
   → Route Optimizer opens automatically

3. Tap **"Optimise Route"**
   → Stops reorder by nearest-neighbour order: CP → India Gate → Humayun's Tomb → Lotus Temple → Qutub Minar → Red Fort
   → Blue polyline appears on map

4. Tap **"Start Day"**
   → GPX replay begins automatically (~5s per dot movement at 6× speed)
   → Blue dot starts moving through Delhi
   → Live polyline + ETA appears within ~5–10 seconds
   → Progress bar shows "Stop 1 of 6" + "0 completed"
   → Trust chip shows 🟢 GPS Good

5. When the dot gets within 100m of a stop:
   → Green "You've arrived!" banner slides in from top
   → Tap "Mark Arrived" → stop card updates, "Next: India Gate" toast slides in

6. Repeat for all 6 stops → Day Complete screen with confetti appears

### Stops in the Demo Route (GPX order)

| # | Place | Closes |
|---|-------|--------|
| 1 | Connaught Place | 21:00 |
| 2 | India Gate | 22:00 |
| 3 | Humayun's Tomb | 18:00 |
| 4 | Lotus Temple | 17:30 |
| 5 | Qutub Minar | 17:00 |
| 6 | Red Fort | 17:30 |

### Debug Bypass Note

The `#if DEBUG` flag in `AppEnvironment.swift` automatically switches between:
- **DEBUG (Xcode run)** → `GPXReplayProvider` (fake GPS from `demo-route.gpx`, 6× speed)
- **Release build** → `LocationService` (real live GPS)

No manual configuration needed.

## Git Workflow

```
main ← develop ← feature/xxx
```

Feature branches → develop for testing → main for release.

## Recent Branches

| Branch | Description |
|---|---|
| `feature/demo-plan-button` | GPX replay infra, Delhi demo plan, live navigation polish (polyline/ETA fix, destination toast, progress labels) |
| `feature/gpx-replay` | `LocationProviding` protocol, `GPXParser`, `GPXReplayProvider`, `AppEnvironment`, `demo-route.gpx` |
| `feature/ui-improvements-v2` | App icon fix, splash tagline, empty state CTA, Netflix profiles |
| `feature/drag-to-reorder-route` | Drag-to-reorder stops, Recalculate button, success toast |
| `feature/gps-route-optimisation` | GPS start point, re-optimise on stop reached, MinHeap |
| `feature/stop-duration-notifications` | Stop duration editor, plan reminder notifications |
| `feature/bug-fixes` | Light/dark theme fix, Settings live theme, logo background fix |
