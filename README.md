# PlanDay — iOS Day Trip Planner

A smart personal day-trip planner built with SwiftUI and MapKit.

Plan a day visiting multiple places → get an optimised route → follow a live itinerary → navigate stop by stop.

## Screenshots

> Run the app in Simulator to preview all screens.

## Tech Stack

| Technology | Usage |
|---|---|
| **SwiftUI** | All UI, declarative layout |
| **MapKit + MKDirections** | Maps, routing, place search |
| **CoreLocation** | Real-time GPS tracking |
| **Swift async/await** | All async calls (no Combine) |
| **@Observable (iOS 17)** | ViewModels, services |
| **FileManager + JSON** | Per-profile trip persistence |
| **@AppStorage / UserDefaults** | Settings, onboarding flag, profiles |

## Features

### Core (FR1–FR9)

| # | Feature | Description |
|---|---|---|
| FR1 | Onboarding | 4-page carousel + name capture, shown once on first launch |
| FR2 | Home Dashboard | Greeting, Today's Focus banner, All Plans list, animated FAB |
| FR3 | Trip/Day Builder | MKLocalSearch place search, stop list, map preview |
| FR4 | Route Optimizer | Nearest-neighbor + MKDirections polyline on full-screen map |
| FR5 | Day Itinerary | Cascading timeline with arrival times and stop durations |
| FR6 | Navigation | Stop-by-stop guidance with Apple Maps launch |
| FR7 | Trip History | Auto-saved plans, history sheet from toolbar |
| FR8 | Settings | Transport mode, appearance (light/dark/system) |
| FR9 | Live Navigation | Real-time GPS, live ETA, auto-arrival detection |

### Upgrades

| # | Upgrade | Description |
|---|---|---|
| U1 | Smart Cards | `DayPlan` + `Trip` models, Day Cards, Trip Cards, animated FAB with two options |
| U2 | Multi-User Profiles | Up to 5 profiles, per-profile data isolation, initials avatar, accent colours |
| U3 | UI Polish + Branding | App icon (blue calendar/map pin), "PlanDay" display name, name-capture onboarding |
| U4 | Edit & Delete | Swipe actions (Edit/Delete) on all cards, pre-filled edit forms, delete confirmation |

## Architecture

MVVM — each screen has its own `View` + `ViewModel`. Services are `@Observable` singletons.

```
DayPlanner/
├── Models/           # DayPlan, Trip, PlanItem, Stop, TravelMode, UserProfile
├── Services/         # RouteService, LocationService, TripHistoryService, ProfileService, ...
├── ViewModels/       # One ViewModel per screen / builder
├── Features/         # One folder per screen
│   ├── Onboarding/
│   ├── Home/
│   ├── DayPlanBuilder/
│   ├── TripBuilder/
│   ├── TripDetail/
│   ├── RouteOptimizer/
│   ├── Itinerary/
│   ├── Navigation/
│   ├── TripHistory/
│   ├── Profiles/
│   └── Settings/
└── Components/       # Reusable views, Color+Hex extension
```

## Key Design Decisions

- **Per-profile persistence** — each profile has its own `history_<uuid>.json` file; switching profiles auto-loads that profile's data
- **Upsert by ID** — `TripHistoryService.save()` replaces existing records by matching ID, so editing a plan never creates duplicates
- **`Color.hex()` static func** — avoids conflict with iOS 26's new `Color(hex: Int)` initialiser
- **No Combine** — all async work uses Swift's native `async/await`

## Running the App

1. Open `DayPlanner/DayPlanner.xcodeproj` in Xcode 15+
2. Select a Simulator (iPhone 15 recommended) or your iPhone
3. Press `Cmd+R`

> **Note:** FR9 Live Navigation requires a real device — GPS is not available in Simulator.

## Git Workflow

```
main ← develop ← feature/xxx
```

All features are developed on `feature/` branches, merged into `develop` for testing, then merged into `main` for release.
