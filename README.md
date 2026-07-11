# DayPlanner iOS

A personal day-trip planner app built with SwiftUI, MapKit, CoreLocation and Swift Concurrency.

Plan a day visiting multiple places → get a smart optimized route → follow a live itinerary → navigate stop by stop.

## Tech Stack

- **SwiftUI** — UI framework
- **MapKit + MKDirections** — maps, routing, place search
- **CoreLocation** — real-time GPS tracking
- **Swift async/await** — all network calls
- **FileManager + JSON** — trip persistence
- **@AppStorage / UserDefaults** — settings

## Features

| # | Feature | Description |
|---|---|---|
| FR1 | Onboarding | 3-page welcome carousel, shown once on first launch |
| FR2 | Home Dashboard | Greeting, today's trip card, quick actions |
| FR3 | Trip Builder | MKLocalSearch place search, stop list, map preview |
| FR4 | Route Optimizer | Nearest-neighbor algorithm + MKDirections polyline |
| FR5 | Day Itinerary | Cascading timeline with editable stop durations |
| FR6 | Navigation | Stop-by-stop guidance with Apple Maps launch |
| FR7 | Trip History | Auto-saved trips, sectioned history list |
| FR8 | Settings | Name, default transport, light/dark/system theme |
| FR9 | Live Navigation | Real-time GPS tracking, live ETA, auto-arrival detection |

## Documentation

- [App Overview](docs/App-Overview.md) — Full feature descriptions in plain language
- [Architecture](docs/Architecture.md) — MVVM structure, file layout, key patterns

## Project Structure

```
DayPlanner/
├── Models/          # Trip, Stop, TravelMode
├── Services/        # RouteService, LocationService, TripHistoryService, ...
├── ViewModels/      # One ViewModel per screen
├── Features/        # One folder per screen (View files)
│   ├── Onboarding/
│   ├── Home/
│   ├── TripBuilder/
│   ├── RouteOptimizer/
│   ├── Itinerary/
│   ├── Navigation/
│   ├── TripHistory/
│   └── Settings/
└── Components/      # Reusable views (TripSummaryCard)
```

## Running the App

1. Open `DayPlanner/DayPlanner.xcodeproj` in Xcode
2. Select a Simulator or your iPhone from the device picker
3. Press `Cmd+R`

> FR9 Live Navigation requires a real device — GPS is not available in Simulator.
