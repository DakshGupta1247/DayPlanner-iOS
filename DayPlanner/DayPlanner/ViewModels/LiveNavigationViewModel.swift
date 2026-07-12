//
//  LiveNavigationViewModel.swift
//  DayPlanner
//
//  ViewModel for FR9 — Live Trip Navigation.
//  Orchestrates GPS tracking, route updates, ETA, and auto-arrival detection.
//
//  FR2 changes:
//  - Breadcrumb tracking uses trustedLocationStream (validated fixes only)
//  - Arrival check uses 25m radius (was 50m)
//  - crossedStopIDs ensures monotonic stop crossing (each stop crossed at most once)
//
//  FR3 changes:
//  - ETAEngine computes EMA-based speed ETA updated every 1s via Timer
//  - etaResult exposed for closing-time verdict display in the view
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

    // Monotonic guard — a stop can only be crossed once
    private var crossedStopIDs: Set<UUID> = []

    var autoArrivedAtStop = false

    // MARK: - ETA
    var etaResult: ETAResult? = nil             // from ETAEngine (speed-based)
    var etaSeconds: Double? = nil               // from MKDirections (road-based)
    var etaIsLoading = false
    private let etaEngine = ETAEngine()
    private var etaTimer: Timer? = nil

    // MARK: - Camera
    var cameraPosition: MapCameraPosition = .automatic

    // MARK: - Arrival banner
    var showingArrivalBanner = false

    // MARK: - Off-route recalculation debounce
    private var lastRouteCalcLocation: CLLocation? = nil

    // Background task handles
    private var trackingTask: Task<Void, Never>? = nil
    private var breadcrumbTask: Task<Void, Never>? = nil

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

    /// Formatted ETA from MKDirections (road-based), falls back to ETAEngine result
    var formattedETA: String {
        if let road = etaSeconds {
            let total = Int(road)
            let hours = total / 3600
            let mins  = (total % 3600) / 60
            if hours > 0 { return "\(hours)h \(mins)m" }
            return "\(mins) min"
        }
        guard let result = etaResult else { return "—" }
        let total = Int(result.durationSeconds)
        let hours = total / 3600
        let mins  = (total % 3600) / 60
        if hours > 0 { return "\(hours)h \(mins)m" }
        return "~\(mins) min"
    }

    var formattedArrivalTime: String {
        guard let result = etaResult else { return "" }
        return result.arrivalTime.formatted(date: .omitted, time: .shortened)
    }

    // MARK: - Start / Stop tracking

    func startLiveTracking() {
        if locationService.isAuthorized {
            locationService.startTracking()
        } else {
            locationService.requestPermission()
        }
        beginObservingLocation()
        beginBreadcrumbTracking()
        startETATimer()
    }

    func stopLiveTracking() {
        locationService.stopTracking()
        trackingTask?.cancel()
        trackingTask = nil
        breadcrumbTask?.cancel()
        breadcrumbTask = nil
        etaTimer?.invalidate()
        etaTimer = nil
    }

    // MARK: - Location observation loop (camera + arrival + route recalc)

    private func beginObservingLocation() {
        trackingTask?.cancel()
        trackingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await withCheckedContinuation { continuation in
                    withObservationTracking {
                        _ = self.locationService.currentLocation
                    } onChange: {
                        continuation.resume()
                    }
                }
                if let location = self.locationService.currentLocation {
                    await self.handleLocationUpdate(location)
                }
            }
        }
    }

    // MARK: - Breadcrumb loop — consumes trustedLocationStream

    private func beginBreadcrumbTracking() {
        breadcrumbTask?.cancel()
        breadcrumbTask = Task { [weak self] in
            guard let self else { return }
            for await location in self.locationService.trustedLocationStream {
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    self.etaEngine.update(newLocation: location)
                    // Refresh speed-based ETA immediately on each trusted fix
                    self.refreshSpeedETA(from: location)
                }
            }
        }
    }

    // MARK: - ETA Timer (1s refresh for arrival time display)

    private func startETATimer() {
        etaTimer?.invalidate()
        etaTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let loc = self.locationService.currentLocation {
                    self.refreshSpeedETA(from: loc)
                }
            }
        }
    }

    private func refreshSpeedETA(from location: CLLocation) {
        guard let stop = currentStop else { return }
        etaResult = etaEngine.eta(to: stop.coordinate, from: location.coordinate)
    }

    // MARK: - Handle each GPS update (camera + arrival + route recalc)

    private func handleLocationUpdate(_ location: CLLocation) async {
        // 1. Update camera
        cameraPosition = .camera(MapCamera(
            centerCoordinate: location.coordinate,
            distance: 800,
            heading: location.course > 0 ? location.course : 0,
            pitch: 45
        ))

        // 2. Arrival check — 25m radius, monotonic guard
        if let stop = currentStop {
            let stopLocation = CLLocation(latitude: stop.latitude, longitude: stop.longitude)
            let distanceToStop = location.distance(from: stopLocation)

            if distanceToStop < 25,
               !showingArrivalBanner,
               !crossedStopIDs.contains(stop.id) {
                crossedStopIDs.insert(stop.id)
                showingArrivalBanner = true
            }
        }

        // 3. Route recalculation (debounced at 50m)
        let shouldRecalculate: Bool
        if let lastCalc = lastRouteCalcLocation {
            shouldRecalculate = location.distance(from: lastCalc) > 50
        } else {
            shouldRecalculate = true
        }

        if shouldRecalculate {
            lastRouteCalcLocation = location
            await recalculateRouteFromCurrentLocation(location)
        }
    }

    // MARK: - Live route calculation (MKDirections)

    private func recalculateRouteFromCurrentLocation(_ location: CLLocation) async {
        guard let stop = currentStop else { return }

        etaIsLoading = true

        let fromItem = MKMapItem(location: location, address: nil)
        let toLocation = CLLocation(latitude: stop.latitude, longitude: stop.longitude)
        let toItem = MKMapItem(location: toLocation, address: nil)

        let request = MKDirections.Request()
        request.source = fromItem
        request.destination = toItem
        request.transportType = trip.travelMode.mkTransportType
        request.requestsAlternateRoutes = false

        do {
            let response = try await MKDirections(request: request).calculate()
            if let best = response.routes.first {
                livePolyline = best.polyline
                etaSeconds   = best.expectedTravelTime
            }
        } catch {
            // Keep last known ETA silently
        }

        etaIsLoading = false
    }

    // MARK: - Intents

    func markCurrentStopArrived() {
        guard currentStopIndex < stops.count else { return }
        currentStopIndex += 1
        showingArrivalBanner = false
        livePolyline = nil
        etaSeconds = nil
        etaResult = nil
        lastRouteCalcLocation = nil
        etaEngine.reset()
    }

    func navigateInMaps() {
        guard let stop = currentStop else { return }
        navigationService.openInAppleMaps(to: stop, mode: trip.travelMode)
    }

    // MARK: - Closing time verdict for current stop

    var closingTimeVerdict: ClosingTimeVerdict {
        guard let stop = currentStop, let result = etaResult else { return .noClosingTime }
        return etaEngine.verdict(eta: result, stop: stop)
    }
}
