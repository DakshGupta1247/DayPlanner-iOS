# DayPlanner — Architecture

## Pattern: MVVM

The app follows MVVM (Model-View-ViewModel). Here's what each layer does:

| Layer | Responsibility | Example files |
|---|---|---|
| **Model** | Pure data, no UI | `Trip.swift`, `Stop.swift` |
| **ViewModel** | Holds screen state, talks to Services | `HomeViewModel.swift` |
| **View** | Displays data from ViewModel, no logic | `HomeView.swift` |
| **Service** | Does the heavy work (network, disk, GPS) | `RouteService.swift` |

The rule: **Views never call Services directly.** They always go through a ViewModel.

---

## File Layout

```
Models/
  Trip.swift                    — Stop, Trip, TravelMode structs

Services/
  RouteService.swift            — MKDirections + nearest-neighbor routing
  PlaceSearchService.swift      — MKLocalSearch with debounce
  NavigationService.swift       — Apple Maps URL launcher + MKDirections steps
  TripHistoryService.swift      — JSON read/write to Documents folder
  LocationService.swift         — CLLocationManager wrapper (@Observable)

ViewModels/
  HomeViewModel.swift           — Home screen state, auto-load/save trip
  TripBuilderViewModel.swift    — Stop list, map camera, search coordination
  RouteOptimizerViewModel.swift — RouteState enum, camera fitting
  ItineraryViewModel.swift      — Cascading arrival times, minute overrides
  NavigationViewModel.swift     — Stop progression, step fetching
  LiveNavigationViewModel.swift — Real-time GPS, ETA, auto-arrival
  TripHistoryViewModel.swift    — Grouped history list, delete
  (Settings has no ViewModel — uses @AppStorage directly)

Features/
  Onboarding/   OnboardingView, OnboardingPageView
  Home/         HomeView
  TripBuilder/  TripBuilderView, PlaceSearchResultRow
  RouteOptimizer/ RouteOptimizerView
  Itinerary/    ItineraryView
  Navigation/   NavigationView, LiveNavigationView
  TripHistory/  TripHistoryView (+ TripDetailView inside)
  Settings/     SettingsView

Components/
  TripSummaryCard.swift         — Reused on Home and TripDetailView
```

---

## Key Swift / SwiftUI Patterns Used

### @Observable (iOS 17+)
Modern replacement for `ObservableObject + @Published`. Any property read inside a SwiftUI `body` is automatically tracked — no need to mark individual properties.

```swift
@Observable
@MainActor
final class HomeViewModel {
    var currentTrip: Trip? = nil   // SwiftUI auto-tracks this
}
```

### @AppStorage
Direct wrapper around UserDefaults. Used for settings (name, appearance, travel mode) and the onboarding flag.

```swift
@AppStorage("userName") private var userName = "there"
```

### actor (thread safety)
`RouteService` and `NavigationService` are Swift actors — Swift guarantees only one piece of code runs inside them at a time, preventing data races during parallel network calls.

### async/await
All network calls (MKDirections, MKLocalSearch, CLLocationManager) use Swift's async/await. No Combine, no callbacks.

### .task modifier
Used instead of `.onAppear + Task {}`. Automatically cancels the async work if the view disappears before it finishes.

---

## Data Flow for Route Calculation

```
User taps "Confirm Trip" in TripBuilderView
    → TripBuilderViewModel.confirmTrip() calls onConfirm closure
    → HomeViewModel.setTrip(trip) saves to TripHistoryService + sets currentTrip
    → HomeView shows TripExistsSection
    → User taps "View Route"
    → RouteOptimizerView appears, .task calls viewModel.calculateRoute()
    → RouteOptimizerViewModel calls RouteService.computeRoute(for:trip)
        → RouteService.nearestNeighborOrder() reorders stops (Haversine distance)
        → RouteService.fetchLeg() calls MKDirections for each consecutive pair
    → Returns ComputedRoute with orderedStops + legs + polylines
    → routeState = .success(route) → SwiftUI re-renders map + bottom card
```

---

## Persistence

Trips are stored as a JSON array at:
```
/var/mobile/.../Documents/trip_history.json
```

- `TripHistoryService.save(_:)` — called automatically when a trip is confirmed
- `TripHistoryService.loadTodaysTrip()` — called in `HomeViewModel.init()` so the trip reappears on launch
- Writes use `.atomic` option — file is never left half-written if the app crashes

---

## Location Tracking (FR9)

```
CLLocationManager (iOS GPS hardware)
    ↓ fires delegate every 10m moved
LocationService (@Observable, @MainActor)
    ↓ currentLocation property updates
LiveNavigationViewModel (observes via withObservationTracking)
    ↓ handleLocationUpdate()
        ├── moves MapCamera (3D tilted view, follows heading)
        ├── checks distance to current stop (auto-arrive at 50m)
        └── recalculates MKDirections from current position (every 50m)
            ↓
LiveNavigationView re-renders map + ETA card
```

---

## Branch Strategy

```
main          ← production-ready code
  └── develop ← integration branch, all FRs merge here first
        └── feature/FR{n}-name ← one branch per feature
```
