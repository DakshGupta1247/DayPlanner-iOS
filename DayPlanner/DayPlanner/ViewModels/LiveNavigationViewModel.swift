//
//  LiveNavigationViewModel.swift
//  DayPlanner
//
//  ViewModel for FR9 — Live Trip Navigation.
//  Orchestrates GPS tracking, route updates, ETA, and auto-arrival detection.
//
//  Key concepts:
//  - Owns a LocationService that streams real-time GPS updates
//  - Every time location changes → checks if user reached the current stop
//    (within 50 metres = "arrived") and recalculates ETA from current position
//  - Route recalculation is debounced: only runs if the user has moved
//    more than 50m from the last calculated position, or after 30 seconds
//  - All state is @MainActor so SwiftUI updates always happen on the main thread
//

import MapKit
import Observation
import CoreLocation
import SwiftUI

@Observable
@MainActor
final class LiveNavigationViewModel {

    // MARK: - Core data
    let trip: Trip
    let route: ComputedRoute
    var stops: [Stop]

    // MARK: - Location
    let locationService = LocationService()

    // The live route polyline from user's current position to next stop
    var livePolyline: MKPolyline? = nil

    // MARK: - Stop progression
    private(set) var currentStopIndex: Int = 0

    // Set to true once user is within 50m of the current stop
    var autoArrivedAtStop = false

    // MARK: - ETA
    var etaSeconds: Double? = nil          // live ETA to next stop in seconds
    var etaIsLoading = false

    // MARK: - Camera
    var cameraPosition: MapCameraPosition = .automatic

    // MARK: - Auto-arrival banner
    var showingArrivalBanner = false

    // MARK: - Off-route recalculation
    // Position where we last calculated the route — used to detect when to recalculate
    private var lastRouteCalcLocation: CLLocation? = nil

    // Background task handle for the location observation loop
    private var trackingTask: Task<Void, Never>? = nil

    private let navigationService = NavigationService()

    init(trip: Trip, route: ComputedRoute) {
        self.trip = trip
        self.route = route
        self.stops = route.orderedStops
    }

    // MARK: - Computed

    var currentStop: Stop? {
        guard currentStopIndex < stops.count else { return nil }
        return stops[currentStopIndex]
    }

    var tripComplete: Bool { currentStopIndex >= stops.count }

    var stopCountLabel: String {
        "\(min(currentStopIndex + 1, stops.count)) of \(stops.count)"
    }

    var completedStops: [Stop] { Array(stops.prefix(currentStopIndex)) }
    var remainingStops: [Stop] { Array(stops.dropFirst(currentStopIndex)) }

    /// Formatted ETA string, e.g. "12 min" or "1h 5m"
    var formattedETA: String {
        guard let eta = etaSeconds else { return "Calculating..." }
        let total = Int(eta)
        let hours = total / 3600
        let mins  = (total % 3600) / 60
        if hours > 0 { return "\(hours)h \(mins)m" }
        return "\(mins) min"
    }

    // MARK: - Start / Stop tracking

    /// Call this when LiveNavigationView appears.
    /// Requests permission if needed, then starts the GPS observation loop.
    func startLiveTracking() {
        if locationService.isAuthorized {
            locationService.startTracking()
        } else {
            locationService.requestPermission()
        }
        beginObservingLocation()
    }

    /// Call this when the view disappears — stops GPS to save battery.
    func stopLiveTracking() {
        locationService.stopTracking()
        trackingTask?.cancel()
        trackingTask = nil
    }

    // MARK: - Location observation loop

    /// Runs a lightweight loop that fires whenever locationService.currentLocation changes.
    /// Uses withObservationTracking — the modern @Observable equivalent of Combine's sink.
    private func beginObservingLocation() {
        trackingTask?.cancel()
        trackingTask = Task { [weak self] in
            // Keep observing until the task is cancelled
            while !Task.isCancelled {
                guard let self else { return }

                await withCheckedContinuation { continuation in
                    // withObservationTracking: runs `apply` once immediately,
                    // then calls `onChange` exactly once when any @Observable
                    // property read inside `apply` changes.
                    withObservationTracking {
                        // Reading currentLocation here "subscribes" to it
                        _ = self.locationService.currentLocation
                    } onChange: {
                        continuation.resume()
                    }
                }

                // Location changed — process the new position
                if let location = self.locationService.currentLocation {
                    await self.handleLocationUpdate(location)
                }
            }
        }
    }

    // MARK: - Handle each GPS update

    private func handleLocationUpdate(_ location: CLLocation) async {
        // 1. Update the map camera to follow the user
        cameraPosition = .camera(MapCamera(
            centerCoordinate: location.coordinate,
            distance: 800,       // metres above ground
            heading: location.course > 0 ? location.course : 0,
            pitch: 45            // tilted 3D view like Apple Maps navigation
        ))

        // 2. Check if user has arrived at the current stop (within 50 metres)
        if let stop = currentStop {
            let stopLocation = CLLocation(latitude: stop.latitude, longitude: stop.longitude)
            let distanceToStop = location.distance(from: stopLocation)

            if distanceToStop < 50 && !showingArrivalBanner {
                showingArrivalBanner = true  // show "You've arrived!" banner
            }
        }

        // 3. Recalculate route only if we've moved 50m+ from the last calculation
        // This prevents hammering MKDirections with every single GPS update
        let shouldRecalculate: Bool
        if let lastCalc = lastRouteCalcLocation {
            shouldRecalculate = location.distance(from: lastCalc) > 50
        } else {
            shouldRecalculate = true  // first calculation
        }

        if shouldRecalculate {
            lastRouteCalcLocation = location
            await recalculateRouteFromCurrentLocation(location)
        }
    }

    // MARK: - Live route calculation

    /// Calls MKDirections from the user's CURRENT GPS position to the next stop.
    /// Updates the polyline drawn on the map and the ETA.
    private func recalculateRouteFromCurrentLocation(_ location: CLLocation) async {
        guard let stop = currentStop else { return }

        etaIsLoading = true

        let fromItem = MKMapItem(location: location, address: nil)
        let toLocation = CLLocation(latitude: stop.latitude, longitude: stop.longitude)
        let toItem   = MKMapItem(location: toLocation, address: nil)

        let request = MKDirections.Request()
        request.source = fromItem
        request.destination = toItem
        request.transportType = trip.travelMode.mkTransportType
        request.requestsAlternateRoutes = false

        do {
            let response = try await MKDirections(request: request).calculate()
            if let best = response.routes.first {
                livePolyline = best.polyline           // update the route line on the map
                etaSeconds   = best.expectedTravelTime // update the ETA
            }
        } catch {
            // Silently ignore — keep showing the last known ETA
        }

        etaIsLoading = false
    }

    // MARK: - Intents

    /// Called when user taps "Arrived" manually, or when auto-arrived.
    func markCurrentStopArrived() {
        guard currentStopIndex < stops.count else { return }
        currentStopIndex += 1
        showingArrivalBanner = false
        livePolyline = nil
        etaSeconds = nil
        lastRouteCalcLocation = nil  // force recalculation for next stop
    }

    /// Opens Apple Maps for the current stop.
    func navigateInMaps() {
        guard let stop = currentStop else { return }
        navigationService.openInAppleMaps(to: stop, mode: trip.travelMode)
    }
}
