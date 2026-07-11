//
//  NavigationViewModel.swift
//  DayPlanner
//
//  Owns the state for the Navigation screen:
//  - Which stop is "current" (next to navigate to)
//  - The step-by-step instructions for that leg
//  - Whether steps are loading
//
//  The user moves through stops one at a time:
//  current stop → mark arrived → advances to next → repeat
//

import MapKit
import Observation

@MainActor
@Observable
final class NavigationViewModel {

    // The optimized list of stops for this trip
    let stops: [Stop]
    let travelMode: TravelMode
    let trip: Trip

    // Index of the stop the user is currently navigating TO
    // (0 = navigating to the first stop)
    private(set) var currentStopIndex: Int = 0

    // In-app step-by-step instructions for the current leg
    private(set) var steps: [NavigationStep] = []

    // Loading state for step fetching
    private(set) var isLoadingSteps = false

    // Error message if step fetch fails
    var stepError: String? = nil

    // Controls whether the steps sheet is expanded
    var isShowingSteps = false

    private let service = NavigationService()

    init(trip: Trip, route: ComputedRoute) {
        self.trip = trip
        self.stops = route.orderedStops
        self.travelMode = trip.travelMode
    }

    // MARK: - Computed

    /// The stop we're currently navigating toward
    var currentStop: Stop? {
        guard currentStopIndex < stops.count else { return nil }
        return stops[currentStopIndex]
    }

    /// True when the user has visited all stops
    var tripComplete: Bool { currentStopIndex >= stops.count }

    /// Progress fraction 0.0 → 1.0 for the progress bar
    var progress: Double {
        guard stops.count > 0 else { return 0 }
        return Double(currentStopIndex) / Double(stops.count)
    }

    /// "Stop 2 of 4" label
    var stopCountLabel: String {
        "\(min(currentStopIndex + 1, stops.count)) of \(stops.count)"
    }

    /// Stops already visited (shown as greyed out)
    var completedStops: [Stop] {
        Array(stops.prefix(currentStopIndex))
    }

    /// Stops still to visit
    var remainingStops: [Stop] {
        Array(stops.dropFirst(currentStopIndex))
    }

    // MARK: - Intents

    /// Opens Apple Maps for turn-by-turn to the current stop
    func navigateInMaps() {
        guard let stop = currentStop else { return }
        service.openInAppleMaps(to: stop, mode: travelMode)
    }

    /// Marks the current stop as visited and advances to the next
    func markCurrentStopArrived() {
        guard currentStopIndex < stops.count else { return }
        currentStopIndex += 1
        steps = []       // clear old steps
        stepError = nil

        // Auto-fetch steps for the next leg
        if currentStopIndex < stops.count {
            Task { await fetchStepsForCurrentLeg() }
        }
    }

    /// Fetches in-app step instructions for the leg leading to the current stop
    func fetchStepsForCurrentLeg() async {
        guard currentStopIndex < stops.count else { return }

        // We need a "from" point — either the previous stop or the first stop itself
        let from: Stop
        if currentStopIndex > 0 {
            from = stops[currentStopIndex - 1]
        } else {
            // First leg — use current stop as both from/to is not meaningful,
            // so we skip step fetching until user has a "from" location
            return
        }

        let to = stops[currentStopIndex]

        isLoadingSteps = true
        stepError = nil

        do {
            steps = try await service.fetchSteps(from: from, to: to, mode: travelMode)
        } catch {
            stepError = error.localizedDescription
            steps = []
        }

        isLoadingSteps = false
    }
}
