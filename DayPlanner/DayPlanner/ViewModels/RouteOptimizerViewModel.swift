//
//  RouteOptimizerViewModel.swift
//  DayPlanner (PlanDay)
//
//  Accepts a DayPlan and computes its optimized route.
//
//  GPS integration (FR1):
//  - LocationService is injected so we can use the user's current GPS position
//    as the invisible starting point for nearest-neighbour optimisation.
//  - If permission is denied or location is unavailable, falls back to the
//    first user-added stop (legacy behaviour) and shows an info banner.
//
//  Re-optimise on stop reached (FR4):
//  - onStopReached(_:) marks a stop visited, removes it from remaining stops,
//    and re-runs optimisation from the user's current GPS position.
//  - Shows a brief "Route updated — X stops remaining" toast after each update.
//
//  Edit-mode state (drag-to-reorder):
//  - isEditingRoute / reorderedStops / hasUserReordered / showDiscardAlert
//  - recalculateWithUserOrder() respects the user's manual sequence.
//

import CoreLocation
import MapKit
import Observation
import SwiftUI

enum RouteState {
    case idle
    case loading
    case success(ComputedRoute)
    case failure(String)
}

@MainActor
@Observable
final class RouteOptimizerViewModel {

    let dayPlan: DayPlan
    var trip: Trip

    var routeState: RouteState = .idle
    var cameraPosition: MapCameraPosition

    // MARK: - GPS

    let locationService = LocationService()
    /// True when GPS is unavailable / denied — drives the info banner in the view
    var showGPSUnavailableBanner = false

    // MARK: - Edit mode (drag-to-reorder)

    var isEditingRoute = false
    var reorderedStops: [Stop] = []
    var hasUserReordered = false
    var showDiscardAlert = false

    // MARK: - Toast banners

    var showSuccessToast = false
    var reoptimiseToastMessage = ""
    var showReoptimiseToast = false

    // MARK: - Re-optimise tracking

    /// Stops remaining after some have been visited (populated by onStopReached)
    private var visitedStopIDs: Set<UUID> = []

    private let routeService = RouteService()

    init(dayPlan: DayPlan) {
        self.dayPlan = dayPlan
        self.trip = Trip(id: dayPlan.id, name: dayPlan.name,
                         date: dayPlan.date, stops: dayPlan.stops,
                         travelMode: dayPlan.travelMode)
        self.cameraPosition = Self.cameraToFit(stops: dayPlan.stops)
    }

    var isLoading: Bool {
        if case .loading = routeState { return true }
        return false
    }

    // MARK: - Initial route calculation (Fix 1 — GPS as starting point)

    func calculateRoute() async {
        // Request GPS permission if not yet determined
        if locationService.authorizationStatus == .notDetermined {
            locationService.requestPermission()
            // Give the system a moment to present the dialog before proceeding
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        locationService.startTracking()

        routeState = .loading

        // Use current GPS location as the invisible origin (Stop #0) if available
        let gpsCoord = locationService.isAuthorized ? locationService.currentLocation?.coordinate : nil
        showGPSUnavailableBanner = (gpsCoord == nil)

        do {
            let route = try await routeService.computeRoute(
                for: dayPlan,
                startingCoordinate: gpsCoord
            )
            routeState = .success(route)
            cameraPosition = Self.cameraToFit(stops: route.orderedStops)
        } catch {
            routeState = .failure(error.localizedDescription)
        }
    }

    // MARK: - Re-optimise after a stop is reached (Fix 2)

    /// Call this when the user physically arrives at a stop (within 50m).
    /// Marks it visited, removes it, and re-optimises the remaining stops
    /// from the user's current GPS position.
    func onStopReached(_ stop: Stop) {
        guard case .success(let currentRoute) = routeState else { return }

        visitedStopIDs.insert(stop.id)
        let remaining = currentRoute.orderedStops.filter { !visitedStopIDs.contains($0.id) }

        guard !remaining.isEmpty else {
            // All stops done — nothing more to optimise
            return
        }

        // Re-optimise is near-instant (no MKDirections needed for ordering),
        // so we don't show a loading state — just update silently then show toast.
        let currentCoord = locationService.currentLocation?.coordinate

        Task {
            do {
                let newRoute: ComputedRoute
                if remaining.count >= 2, let coord = currentCoord {
                    newRoute = try await routeService.computeRoute(
                        remainingStops: remaining,
                        from: coord,
                        travelMode: dayPlan.travelMode
                    )
                } else if remaining.count >= 2 {
                    // GPS unavailable — re-optimise without a starting coordinate
                    newRoute = try await routeService.computeRoute(
                        orderedStops: remaining,
                        travelMode: dayPlan.travelMode
                    )
                } else {
                    // Only 1 stop left — no optimisation needed, just rebuild legs
                    newRoute = try await routeService.computeRoute(
                        orderedStops: remaining,
                        travelMode: dayPlan.travelMode
                    )
                }
                routeState = .success(newRoute)
                cameraPosition = Self.cameraToFit(stops: newRoute.orderedStops)
                trip = Trip(id: dayPlan.id, name: dayPlan.name,
                            date: dayPlan.date, stops: newRoute.orderedStops,
                            travelMode: dayPlan.travelMode)
                // Show re-optimise toast
                reoptimiseToastMessage = "Route updated — \(remaining.count) stop\(remaining.count == 1 ? "" : "s") remaining"
                showReoptimiseToast = true
                Task {
                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                    showReoptimiseToast = false
                }
            } catch {
                // Silently ignore re-optimise errors — keep existing route
            }
        }
    }

    // MARK: - Recalculate with user-defined order (drag-to-reorder)

    func recalculateWithUserOrder() async {
        guard !reorderedStops.isEmpty else { return }
        routeState = .loading
        do {
            let route = try await routeService.computeRoute(
                orderedStops: reorderedStops,
                travelMode: dayPlan.travelMode
            )
            routeState = .success(route)
            cameraPosition = Self.cameraToFit(stops: route.orderedStops)
            trip = Trip(id: dayPlan.id, name: dayPlan.name,
                        date: dayPlan.date, stops: reorderedStops,
                        travelMode: dayPlan.travelMode)
            isEditingRoute = false
            hasUserReordered = false
            showSuccessToast = true
            Task {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                showSuccessToast = false
            }
        } catch {
            routeState = .failure(error.localizedDescription)
            isEditingRoute = false
        }
    }

    // MARK: - Edit mode helpers

    func enterEditMode() {
        guard case .success(let route) = routeState else { return }
        reorderedStops = route.orderedStops
        hasUserReordered = false
        isEditingRoute = true
    }

    func moveStop(from source: IndexSet, to destination: Int) {
        reorderedStops.move(fromOffsets: source, toOffset: destination)
        hasUserReordered = true
    }

    func requestCancelEdit() {
        if hasUserReordered {
            showDiscardAlert = true
        } else {
            isEditingRoute = false
        }
    }

    func discardEdits() {
        reorderedStops = []
        hasUserReordered = false
        isEditingRoute = false
        showDiscardAlert = false
    }

    // MARK: - Camera

    static func cameraToFit(stops: [Stop]) -> MapCameraPosition {
        guard !stops.isEmpty else { return .automatic }
        if stops.count == 1 {
            return .region(MKCoordinateRegion(
                center: stops[0].coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            ))
        }
        let lats = stops.map(\.latitude); let lons = stops.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude:  (lats.min()! + lats.max()!) / 2,
            longitude: (lons.min()! + lons.max()!) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta:  (lats.max()! - lats.min()!) * 1.4,
            longitudeDelta: (lons.max()! - lons.min()!) * 1.4
        )
        return .region(MKCoordinateRegion(center: center, span: span))
    }
}
