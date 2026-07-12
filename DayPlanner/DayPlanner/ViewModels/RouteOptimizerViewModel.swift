//
//  RouteOptimizerViewModel.swift
//  DayPlanner (PlanDay)
//
//  Accepts a DayPlan and computes its optimized route.
//  Keeps a Trip reference so NavigationView / ItineraryView can still receive it.
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
    let trip: Trip          // synthetic single-day trip for downstream views

    var routeState: RouteState = .idle
    var cameraPosition: MapCameraPosition

    private let routeService = RouteService()

    init(dayPlan: DayPlan) {
        self.dayPlan = dayPlan
        // Wrap in a Trip so NavigationView / ItineraryView receive the same type
        self.trip = Trip(id: dayPlan.id, name: dayPlan.name,
                         date: dayPlan.date, stops: dayPlan.stops,
                         travelMode: dayPlan.travelMode)
        self.cameraPosition = Self.cameraToFit(stops: dayPlan.stops)
    }

    var isLoading: Bool {
        if case .loading = routeState { return true }
        return false
    }

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

    private static func cameraToFit(stops: [Stop]) -> MapCameraPosition {
        guard !stops.isEmpty else { return .automatic }
        if stops.count == 1 {
            return .region(MKCoordinateRegion(
                center: stops[0].coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            ))
        }
        let lats = stops.map(\.latitude);  let lons = stops.map(\.longitude)
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
