//
//  RouteOptimizerViewModel.swift
//  DayPlanner (PlanDay)
//
//  Accepts a DayPlan and computes its optimized route.
//
//  ROOT CAUSE OF GPS FALLBACK BUG (always showing banner on real device):
//  The old calculateRoute() called startTracking() then immediately read
//  currentLocation on the very next line — the GPS chip hadn't had time to
//  deliver its first fix, so currentLocation was always nil, and the fallback
//  banner always fired.
//
//  Additionally, LocationIntegrityGate was rejecting the first cached fix
//  that Core Location delivers on a real device (often 10–60s old), because
//  the old 5-second staleness check treated it as .untrusted.
//
//  Fix:
//  1. calculateRoute() now waits up to 5 seconds for the first trusted fix
//     via waitForLocation(timeout:) before running optimisation.
//  2. LocationIntegrityGate's first-fix path is now lenient (no staleness/
//     teleport check when previous == nil).
//  3. A new .locating RouteState drives a "📍 Getting your location..." card
//     in the UI so the user sees the app is actively trying to get GPS.
//  4. If GPS is denied → skip wait, show banner, optimise with first stop.
//  5. If GPS times out (5s) → fallback gracefully, show banner.
//

import CoreLocation
import MapKit
import Observation
import SwiftUI

enum RouteState {
    case idle
    case locating      // waiting for first GPS fix (new)
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
        switch routeState {
        case .loading, .locating: return true
        default: return false
        }
    }

    // MARK: - GPS wait helper

    /// Waits up to `timeout` seconds for the first trusted GPS fix.
    /// Returns the coordinate immediately if one is already available.
    /// Returns nil if denied, timeout reached, or no fix arrives.
    private func waitForLocation(timeout: TimeInterval = 5.0) async -> CLLocationCoordinate2D? {
        // Already have a fix — return it immediately
        if let loc = locationService.currentLocation, locationService.hasReceivedFirstFix {
            return loc.coordinate
        }

        // Capture the stream on MainActor before entering the task group
        let stream = locationService.trustedLocationStream

        // Race the stream against a timeout
        return await withTaskGroup(of: CLLocationCoordinate2D?.self) { group in
            // Task 1: wait for first fix from trustedLocationStream
            group.addTask {
                for await location in stream {
                    return location.coordinate
                }
                return nil
            }

            // Task 2: timeout after N seconds
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                return nil
            }

            // Return whichever finishes first (fix OR timeout), cancel the other
            let result = await group.next() ?? nil
            group.cancelAll()
            return result
        }
    }

    // MARK: - Initial route calculation

    func calculateRoute() async {
        // Step 1: Handle permission
        if locationService.isDenied {
            // User has explicitly denied — skip GPS, run immediately with fallback
            showGPSUnavailableBanner = true
            routeState = .loading
            await runOptimise(startingCoordinate: nil)
            return
        }

        if locationService.authorizationStatus == .notDetermined {
            locationService.requestPermission()
            // Give the system dialog time to appear and for user to respond
            try? await Task.sleep(nanoseconds: 800_000_000)
        }

        // Step 2: Start tracking and show "Getting your location..." state
        locationService.startTracking()
        routeState = .locating

        // Step 3: Wait up to 5s for the first trusted GPS fix
        let gpsCoord = await waitForLocation(timeout: 5.0)

        // Step 4: Show banner only if truly no fix arrived
        showGPSUnavailableBanner = (gpsCoord == nil)

        // Step 5: Run optimisation with whatever we got
        routeState = .loading
        await runOptimise(startingCoordinate: gpsCoord)
    }

    private func runOptimise(startingCoordinate: CLLocationCoordinate2D?) async {
        do {
            let route = try await routeService.computeRoute(
                for: dayPlan,
                startingCoordinate: startingCoordinate
            )
            routeState = .success(route)
            cameraPosition = Self.cameraToFit(stops: route.orderedStops)
        } catch {
            routeState = .failure(error.localizedDescription)
        }
    }

    // MARK: - Re-optimise after a stop is reached

    func onStopReached(_ stop: Stop) {
        guard case .success(let currentRoute) = routeState else { return }

        visitedStopIDs.insert(stop.id)
        let remaining = currentRoute.orderedStops.filter { !visitedStopIDs.contains($0.id) }

        guard !remaining.isEmpty else { return }

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
                } else {
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
                reoptimiseToastMessage = "Route updated — \(remaining.count) stop\(remaining.count == 1 ? "" : "s") remaining"
                showReoptimiseToast = true
                Task {
                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                    showReoptimiseToast = false
                }
            } catch {
                // Silently keep existing route on re-optimise failure
            }
        }
    }

    // MARK: - Recalculate with user-defined order

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
