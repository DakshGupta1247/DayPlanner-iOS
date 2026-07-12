//
//  ItineraryViewModel.swift
//  DayPlanner
//
//  ViewModel for the Day Itinerary / Timeline screen.
//
//  This ViewModel takes a Trip and a ComputedRoute and calculates:
//  - What time the user arrives at each stop
//  - What time they leave each stop
//  - What time they arrive at the NEXT stop
//
//  The key insight: arrival time at stop N =
//    departure time from stop (N-1) + travel time of leg (N-1 → N)
//
//  And departure time from stop N =
//    arrival time at stop N + minutesToSpend at stop N
//
//  This creates a cascading chain — change the start time or any
//  "time to spend" and all subsequent times update automatically.
//  That's why everything is computed from a single source of truth.
//

import Foundation
import Observation

/// A single row in the itinerary timeline — wraps a Stop with computed times.
struct ItineraryEntry: Identifiable {
    let id: UUID           // same as the stop's id
    var stop: Stop
    let arrivalTime: Date
    let departureTime: Date
    let travelTimeToNext: TimeInterval?   // nil for the last stop
    let distanceToNext: Double?           // metres, nil for last stop

    /// Actual minutes at this stop — derived from departure/arrival gap so it reflects overrides.
    var effectiveMinutes: Int {
        Int(departureTime.timeIntervalSince(arrivalTime) / 60)
    }

    var formattedArrival: String {
        arrivalTime.formatted(date: .omitted, time: .shortened)
    }

    var formattedDeparture: String {
        departureTime.formatted(date: .omitted, time: .shortened)
    }

    var formattedTravelToNext: String? {
        guard let t = travelTimeToNext else { return nil }
        let mins = Int(t / 60)
        return mins < 60 ? "\(mins) min" : "\(mins/60)h \(mins%60)m"
    }

    var formattedDistanceToNext: String? {
        guard let d = distanceToNext else { return nil }
        if d < 1000 { return String(format: "%.0f m", d) }
        return String(format: "%.1f km", d / 1000)
    }
}

@MainActor
@Observable
final class ItineraryViewModel {

    // The trip being displayed
    let trip: Trip

    // The computed route from FR4 (has optimized order + leg times)
    let route: ComputedRoute

    // What time the user plans to start their day — default 9:00 AM today
    var startTime: Date

    // Controls the time picker sheet visibility
    var isEditingStartTime = false

    // MARK: - Computed timeline

    /// The full ordered timeline, recalculated whenever startTime or
    /// any stop's minutesToSpend changes.
    var entries: [ItineraryEntry] {
        buildEntries()
    }

    /// Total time from departure at stop 1 to arrival at last stop
    var totalDuration: String {
        guard let first = entries.first, let last = entries.last else { return "—" }
        let seconds = last.arrivalTime.timeIntervalSince(first.arrivalTime)
        let hours = Int(seconds) / 3600
        let mins  = (Int(seconds) % 3600) / 60
        return hours > 0 ? "\(hours)h \(mins)m" : "\(mins) min"
    }

    /// Projected finish time (departure from last stop)
    var finishTime: String {
        entries.last?.formattedDeparture ?? "—"
    }

    init(trip: Trip, route: ComputedRoute) {
        self.trip = trip
        self.route = route
        // Use the day plan's stored start time if available, otherwise default to 9 AM
        if let dayStartTime = trip.days.first?.startTime {
            self.startTime = dayStartTime
        } else {
            var c = Calendar.current.dateComponents([.year, .month, .day], from: .now)
            c.hour = 9; c.minute = 0
            self.startTime = Calendar.current.date(from: c) ?? .now
        }
    }

    // MARK: - Intent

    /// Updates the minutesToSpend for a specific stop.
    /// Because entries is a computed property, the timeline immediately
    /// recalculates and the View re-renders automatically.
    func updateMinutesToSpend(for entry: ItineraryEntry, minutes: Int) {
        // Find the stop in the route's orderedStops and update it.
        // Note: route.orderedStops is a let, so we work with a local mutable copy
        // via the entries builder — for now we store overrides in a dictionary.
        minuteOverrides[entry.id] = max(5, minutes) // minimum 5 minutes
    }

    // Local overrides for minutesToSpend — lets user adjust without mutating the model
    // Key = stop id, Value = overridden minutes
    private var minuteOverrides: [UUID: Int] = [:]

    // MARK: - Timeline builder

    private func buildEntries() -> [ItineraryEntry] {
        let stops = route.orderedStops
        let legs  = route.legs
        guard !stops.isEmpty else { return [] }

        var entries: [ItineraryEntry] = []
        var currentTime = startTime

        for (index, stop) in stops.enumerated() {
            let arrivalTime = currentTime

            // Use override if set, otherwise the stop's original minutesToSpend
            let minutes = minuteOverrides[stop.id] ?? stop.minutesToSpend
            let departureTime = arrivalTime.addingTimeInterval(TimeInterval(minutes * 60))

            // Travel info to the NEXT stop (from this leg)
            let leg = index < legs.count ? legs[index] : nil

            entries.append(ItineraryEntry(
                id: stop.id,
                stop: stop,
                arrivalTime: arrivalTime,
                departureTime: departureTime,
                travelTimeToNext: leg?.travelTimeSeconds,
                distanceToNext: leg?.distanceMeters
            ))

            // Next stop's arrival = this stop's departure + travel time
            currentTime = departureTime.addingTimeInterval(leg?.travelTimeSeconds ?? 0)
        }

        return entries
    }
}
