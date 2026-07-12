# PlanDay — iOS Day Trip Planner

A smart personal day-trip planner built with SwiftUI and MapKit.

Plan a day visiting multiple places → get a GPS-aware optimised route → follow a live itinerary → navigate stop by stop.

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
| FR9 | Live Navigation | ✅ | Real-time GPS, live ETA, auto-arrival detection at 50m |

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

## Architecture

MVVM — each screen has its own `View` + `ViewModel`. Services are `@Observable` singletons.

```
DayPlanner/
├── Models/           # DayPlan, Trip, Stop, PlanItem, TravelMode, UserProfile
├── Services/         # RouteService, LocationService, TripHistoryService,
│                     # ProfileService, NotificationService, PlaceSearchService,
│                     # NavigationService, MinHeap
├── ViewModels/       # One ViewModel per screen / builder
├── Features/
│   ├── Splash/       # SplashScreenView, WelcomeScreenView
│   ├── Onboarding/   # OnboardingView, OnboardingPageView
│   ├── Home/         # HomeView
│   ├── Profiles/     # ProfileCreationView, ProfileSelectionView, ProfileSwitcherView
│   ├── DayPlanBuilder/
│   ├── TripBuilder/
│   ├── TripDetail/
│   ├── RouteOptimizer/
│   ├── Itinerary/
│   ├── Navigation/   # NavigationView, LiveNavigationView
│   ├── TripHistory/
│   └── Settings/
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

## Running the App

1. Open `DayPlanner/DayPlanner.xcodeproj` in Xcode 15+
2. Select a Simulator (iPhone 16 Pro recommended) or your iPhone
3. Press `Cmd+R`

> **GPS Testing in Simulator:** Debug → Simulate Location → pick a city, or Features → Location → Custom Location in the simulator window.

> **Live Navigation (FR9):** Full GPS tracking works best on a real device.

## Git Workflow

```
main ← develop ← feature/xxx
```

Feature branches → develop for testing → main for release.

## Recent Branches

| Branch | Description |
|---|---|
| `feature/ui-improvements-v2` | App icon fix, splash tagline, empty state CTA, Netflix profiles |
| `feature/drag-to-reorder-route` | Drag-to-reorder stops, Recalculate button, success toast |
| `feature/gps-route-optimisation` | GPS start point, re-optimise on stop reached, MinHeap |
| `feature/stop-duration-notifications` | Stop duration editor, plan reminder notifications |
| `feature/bug-fixes` | Light/dark theme fix, Settings live theme, logo background fix |
