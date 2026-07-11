//
//  TripHistoryViewModel.swift
//  DayPlanner
//
//  ViewModel for the Trip History screen.
//  Loads the saved trips list from TripHistoryService and exposes
//  a delete intent that the View can call.
//

import Foundation
import Observation

@Observable
@MainActor
final class TripHistoryViewModel {

    // The full list of saved trips — displayed in TripHistoryView
    var trips: [Trip] = []

    // Grouped by: Today, This Week, Earlier
    var groupedTrips: [(title: String, trips: [Trip])] {
        let calendar = Calendar.current
        let today     = calendar.startOfDay(for: .now)
        let weekStart = calendar.date(byAdding: .day, value: -6, to: today)!

        let todayTrips   = trips.filter { calendar.isDateInToday($0.date) }
        let weekTrips    = trips.filter {
            let d = calendar.startOfDay(for: $0.date)
            return d >= weekStart && d < today   // not today, but within the past 6 days
        }
        let earlierTrips = trips.filter {
            calendar.startOfDay(for: $0.date) < weekStart
        }

        // Only include groups that have at least one trip
        return [
            ("Today",      todayTrips),
            ("This Week",  weekTrips),
            ("Earlier",    earlierTrips)
        ].filter { !$0.trips.isEmpty }
    }

    // MARK: - Intents

    /// Loads (or reloads) trips from disk. Call this when the view appears.
    func loadTrips() {
        trips = TripHistoryService.shared.loadAll()
    }

    /// Deletes one or more trips at the given offsets within a section.
    func delete(tripID: UUID) {
        TripHistoryService.shared.delete(tripID: tripID)
        trips.removeAll { $0.id == tripID }
    }
}
