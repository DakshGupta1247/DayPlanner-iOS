//
//  RouteOptimizerViewModel.swift
//  DayPlanner
//
//  ViewModel for the Route Optimizer screen.
//  Owns the loading state, the computed route, and the map camera.
//
//  Why @MainActor on the class?
//  All UI updates must happen on the main thread. Marking the whole class
//  @MainActor means every property write automatically happens on the
//  main thread — we never need to manually dispatch to main.
//
//  The heavy work (MKDirections network calls, nearest-neighbor sorting)
//  happens inside RouteService (an actor), which runs off the main thread.
//  When it's done, results are assigned back here on the main thread.
//

import MapKit
import Observation
import SwiftUI

// Describes what the screen should show at any moment
enum RouteState {
    case idle                          // haven't started yet
    case loading                       // waiting for MKDirections
    case success(ComputedRoute)        // route is ready to display
    case failure(String)               // something went wrong
}

@MainActor
@Observable
final class RouteOptimizerViewModel {

    // The trip whose stops we are routing
    let trip: Trip

    // Current state of the route calculation
    var routeState: RouteState = .idle

    // Map camera — starts zoomed to fit all stops, updates after route loads
    var cameraPosition: MapCameraPosition

    // The service that does the heavy lifting (off main thread via actor)
    private let routeService = RouteService()

    init(trip: Trip) {
        self.trip = trip
        // Zoom the initial camera to fit all stop coordinates
        self.cameraPosition = Self.cameraToFit(stops: trip.stops)
    }

    // MARK: - Computed

    /// True while a route calculation is in flight — used to disable the refresh button
    var isLoading: Bool {
        if case .loading = routeState { return true }
        return false
    }

    // MARK: - Intents

    /// Kicks off route calculation. Called when the view appears or
    /// when the user taps "Recalculate".
    func calculateRoute() async {
        routeState = .loading

        do {
            // RouteService is an actor — calling it here automatically
            // suspends on the main thread and resumes when the actor is free.
            let route = try await routeService.computeRoute(for: trip)
            routeState = .success(route)

            // After route loads, re-fit the camera to the optimized order
            cameraPosition = Self.cameraToFit(stops: route.orderedStops)
        } catch {
            routeState = .failure(error.localizedDescription)
        }
    }

    // MARK: - Helpers

    /// Computes a map region that fits all stop coordinates with padding.
    private static func cameraToFit(stops: [Stop]) -> MapCameraPosition {
        guard !stops.isEmpty else {
            return .automatic
        }

        if stops.count == 1 {
            return .region(MKCoordinateRegion(
                center: stops[0].coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            ))
        }

        // Find the bounding box of all coordinates
        let lats = stops.map(\.latitude)
        let lons = stops.map(\.longitude)
        let minLat = lats.min()!, maxLat = lats.max()!
        let minLon = lons.min()!, maxLon = lons.max()!

        let center = CLLocationCoordinate2D(
            latitude:  (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        // Add 40% padding around the bounding box so pins aren't at the edge
        let span = MKCoordinateSpan(
            latitudeDelta:  (maxLat - minLat) * 1.4,
            longitudeDelta: (maxLon - minLon) * 1.4
        )
        return .region(MKCoordinateRegion(center: center, span: span))
    }
}
