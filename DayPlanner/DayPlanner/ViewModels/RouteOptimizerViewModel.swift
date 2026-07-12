//
//  RouteOptimizerViewModel.swift
//  DayPlanner (PlanDay)
//
//  Accepts a DayPlan and computes its optimized route.
//  Keeps a Trip reference so NavigationView / ItineraryView can still receive it.
//
//  Edit-mode state:
//  isEditingRoute    — true while the drag-to-reorder list is shown
//  reorderedStops    — working copy of stops the user is dragging around
//  hasUserReordered  — true once the user makes at least one move
//  showDiscardAlert  — shown when Cancel is tapped after a reorder change
//  showSuccessToast  — shown for 2.5s after a successful recalculation
//

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
    var trip: Trip          // synthetic single-day trip for downstream views

    var routeState: RouteState = .idle
    var cameraPosition: MapCameraPosition

    // MARK: - Edit mode state

    var isEditingRoute = false
    var reorderedStops: [Stop] = []
    var hasUserReordered = false
    var showDiscardAlert = false
    var showSuccessToast = false

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

    // MARK: - Route calculation

    func calculateRoute() async {
        routeState = .loading
        do {
            let route = try await routeService.computeRoute(for: dayPlan)
            routeState = .success(route)
            cameraPosition = Self.cameraToFit(stops: route.orderedStops)
        } catch {
            routeState = .failure(error.localizedDescription)
        }
    }

    /// Recalculates the route using the user's manually reordered stop sequence.
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
            // Update the synthetic trip so Itinerary/Navigation use the new order
            trip = Trip(id: dayPlan.id, name: dayPlan.name,
                        date: dayPlan.date, stops: reorderedStops,
                        travelMode: dayPlan.travelMode)
            isEditingRoute = false
            hasUserReordered = false
            showSuccessToast = true
            // Auto-dismiss toast after 2.5 seconds
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

    /// Called when the user taps Cancel in edit mode.
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
