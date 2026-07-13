//
//  LiveNavigationViewModel.swift
//  DayPlanner
//
//  ViewModel for FR9 — Live Trip Navigation.
//  Orchestrates GPS tracking, route updates, ETA, and auto-arrival detection.
//
//  Day Complete flow:
//  - checkIfDayComplete() is called after every stop arrival
//  - When all stops are marked arrived, a 0.8s delay fires then isDayComplete = true
//  - daySummary is computed at that moment and passed to DayCompleteView
//  - The plan is saved back to TripHistoryService so history shows the completion
//

import MapKit
import Observation
import CoreLocation
import SwiftUI

// MARK: - DaySummary

struct DaySummary {
    let totalStops: Int
    let completedStops: Int
    let startTime: Date
    let endTime: Date

    var timeTaken: String {
        let minutes = Int(endTime.timeIntervalSince(startTime) / 60)
        guard minutes > 0 else { return "< 1 min" }
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m > 0 ? "\(h)h \(m)min" : "\(h)h"
        }
        return "\(minutes) min"
    }
}

@Observable
@MainActor
final class LiveNavigationViewModel {

    // MARK: - Core data
    let trip: Trip
    let route: ComputedRoute
    var stops: [Stop]

    // MARK: - Location
    let locationService: LocationProviding

    var livePolyline: MKPolyline? = nil

    // MARK: - Stop progression
    private(set) var currentStopIndex: Int = 0
    private var crossedStopIDs: Set<UUID> = []
    var autoArrivedAtStop = false

    // MARK: - ETA
    var etaResult: ETAResult? = nil
    var etaSeconds: Double? = nil
    var etaIsLoading = false
    private let etaEngine = ETAEngine()
    private var etaTimer: Timer? = nil

    // MARK: - Camera
    var cameraPosition: MapCameraPosition = .automatic

    // MARK: - Arrival banner
    var showingArrivalBanner = false

    // MARK: - Destination updated toast
    var destinationToast: String? = nil
    private var toastClearTask: Task<Void, Never>? = nil

    // MARK: - Day Complete
    var isDayComplete = false
    var daySummary: DaySummary? = nil
    private let dayStartTime: Date = .now

    // MARK: - Off-route recalculation debounce
    private var lastRouteCalcLocation: CLLocation? = nil
    // Generation counter — incremented each time we advance to a new stop.
    // Prevents a stale in-flight MKDirections response from overwriting fresh state.
    private var routeCalcGeneration = 0
    private var routeCalcInFlight = false

    private var trackingTask: Task<Void, Never>? = nil
    private var breadcrumbTask: Task<Void, Never>? = nil
    private var routeCalcTask: Task<Void, Never>? = nil

    private let navigationService = NavigationService()

    init(trip: Trip, route: ComputedRoute, locationProvider: LocationProviding = AppEnvironment.locationProvider) {
        self.trip = trip
        self.route = route
        self.stops = route.orderedStops
        self.locationService = locationProvider
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

    var completedCount: Int { currentStopIndex }
    var totalCount: Int { stops.count }
    var progressFraction: Double {
        guard stops.count > 0 else { return 0 }
        return Double(currentStopIndex) / Double(stops.count)
    }

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

    var closingTimeVerdict: ClosingTimeVerdict {
        guard let stop = currentStop, let result = etaResult else { return .noClosingTime }
        return etaEngine.verdict(eta: result, stop: stop)
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
        trackingTask?.cancel(); trackingTask = nil
        breadcrumbTask?.cancel(); breadcrumbTask = nil
        routeCalcTask?.cancel(); routeCalcTask = nil
        etaTimer?.invalidate(); etaTimer = nil
        toastClearTask?.cancel(); toastClearTask = nil
    }

    // MARK: - Location observation loop

    private func beginObservingLocation() {
        trackingTask?.cancel()
        // Single consumer of trustedLocationStream — handles both arrival detection
        // and ETA updates in one loop. AsyncStream only supports one active consumer;
        // having two separate tasks (tracking + breadcrumb) caused one to starve the
        // other, meaning arrival detection missed most GPX fixes.
        trackingTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for await location in self.locationService.trustedLocationStream {
                guard !Task.isCancelled else { break }
                self.etaEngine.update(newLocation: location)
                self.refreshSpeedETA(from: location)
                self.handleLocationUpdate(location)
            }
        }
    }

    // MARK: - Breadcrumb loop (merged into beginObservingLocation above)

    private func beginBreadcrumbTracking() {
        // No-op — breadcrumb tracking is now handled in the single stream consumer
        // inside beginObservingLocation() to avoid dual-consumer stream starvation.
    }

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

    // MARK: - Handle each GPS update

    private func handleLocationUpdate(_ location: CLLocation) {
        // Camera update — synchronous, no await needed
        cameraPosition = .camera(MapCamera(
            centerCoordinate: location.coordinate,
            distance: 800,
            heading: location.course > 0 ? location.course : 0,
            pitch: 45
        ))

        // Arrival detection
        if let stop = currentStop {
            let stopLocation = CLLocation(latitude: stop.latitude, longitude: stop.longitude)
            let distanceToStop = location.distance(from: stopLocation)

            if distanceToStop < 100,
               !showingArrivalBanner,
               !crossedStopIDs.contains(stop.id) {
                crossedStopIDs.insert(stop.id)
                showingArrivalBanner = true
            }
        }

        // Route recalculation — only start a new request when we've moved enough
        // AND no request is already in flight. Never cancel an active MKDirections
        // call mid-flight — it would prevent the polyline from ever appearing.
        let shouldRecalculate: Bool
        if let lastCalc = lastRouteCalcLocation {
            shouldRecalculate = location.distance(from: lastCalc) > 150
        } else {
            shouldRecalculate = true
        }

        if shouldRecalculate && !routeCalcInFlight {
            lastRouteCalcLocation = location
            let generation = routeCalcGeneration
            routeCalcInFlight = true
            routeCalcTask = Task { [weak self] in
                await self?.recalculateRoute(from: location, generation: generation)
                await MainActor.run { [weak self] in
                    self?.routeCalcInFlight = false
                    self?.routeCalcTask = nil
                }
            }
        }
    }

    // MARK: - Live route calculation

    private func recalculateRoute(from location: CLLocation, generation: Int) async {
        guard let stop = currentStop else { return }
        etaIsLoading = true
        let transportType = trip.travelMode.mkTransportType
        let destCoord = CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude)
        let fromItem = MKMapItem(placemark: MKPlacemark(coordinate: location.coordinate))
        let toItem = MKMapItem(placemark: MKPlacemark(coordinate: destCoord))
        let request = MKDirections.Request()
        request.source = fromItem
        request.destination = toItem
        request.transportType = transportType
        request.requestsAlternateRoutes = false
        do {
            let response = try await MKDirections(request: request).calculate()
            // Discard result if we've already advanced to a new stop
            guard generation == routeCalcGeneration else { return }
            if let best = response.routes.first {
                livePolyline = best.polyline
                etaSeconds   = best.expectedTravelTime
            }
        } catch { }
        if generation == routeCalcGeneration {
            etaIsLoading = false
        }
    }

    // MARK: - Intents

    func markCurrentStopArrived() {
        guard currentStopIndex < stops.count else { return }
        currentStopIndex += 1
        routeCalcGeneration += 1   // invalidate any in-flight MKDirections response
        routeCalcTask?.cancel(); routeCalcTask = nil
        routeCalcInFlight = false
        showingArrivalBanner = false
        livePolyline = nil
        etaSeconds = nil
        etaResult = nil
        etaIsLoading = false
        lastRouteCalcLocation = nil
        etaEngine.reset()
        showDestinationToast()
        checkIfDayComplete()
    }

    private func showDestinationToast() {
        guard currentStopIndex < stops.count else { return }
        let nextName = stops[currentStopIndex].name
        destinationToast = "Next: \(nextName)"
        toastClearTask?.cancel()
        toastClearTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: 2_500_000_000)
                self?.destinationToast = nil
            } catch {
                // Task was cancelled (new stop arrived) — leave the new toast visible
            }
        }
    }

    func navigateInMaps() {
        guard let stop = currentStop else { return }
        navigationService.openInAppleMaps(to: stop, mode: trip.travelMode)
    }

    // MARK: - Day Complete detection

    private func checkIfDayComplete() {
        guard currentStopIndex >= stops.count, !stops.isEmpty else { return }

        let summary = DaySummary(
            totalStops: stops.count,
            completedStops: stops.count,
            startTime: dayStartTime,
            endTime: .now
        )

        // 0.8s delay so the arrival animation finishes before the sheet appears
        Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 800_000_000)
            self.daySummary = summary
            self.isDayComplete = true
            self.saveCompletedPlan()
        }
    }

    private func saveCompletedPlan() {
        // Build a DayPlan with isManuallyCompleted = true so the home screen card
        // immediately greys out — status no longer depends on the date alone.
        var dayPlan = trip.days.first ?? DayPlan(
            id: trip.id,
            name: trip.name,
            date: .now,
            stops: stops,
            travelMode: trip.travelMode
        )
        dayPlan.isManuallyCompleted = true
        TripHistoryService.shared.save(PlanItem.singleDay(dayPlan))
    }
}
