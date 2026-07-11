//
//  HomeViewModel.swift
//  DayPlanner
//
//  The ViewModel for the Home screen — sits between the Model (Trip) and the View (HomeView).
//
//  MVVM recap:
//  - Model   = Trip.swift (pure data, no UI knowledge)
//  - ViewModel = this file (holds state, has logic, no SwiftUI views)
//  - View    = HomeView.swift (only reads from ViewModel, never does logic itself)
//
//  Why @Observable?
//  @Observable (iOS 17+) is the modern replacement for ObservableObject + @Published.
//  Any property you read inside a SwiftUI View body is automatically tracked —
//  when it changes, only the views that read it re-render. Cleaner and faster.
//

import Foundation
import Observation  // needed for @Observable

@Observable
final class HomeViewModel {

    // The current day's trip. nil means no trip has been planned yet.
    // When this changes, HomeView automatically re-renders.
    var currentTrip: Trip? = nil

    // Controls whether the "Plan Your Day" sheet is presented
    var isShowingTripBuilder = false

    init() {
        // Auto-load today's trip from disk when the app opens.
        // If the user already planned a trip today, it shows up immediately.
        currentTrip = TripHistoryService.shared.loadTodaysTrip()
    }

    // MARK: - Computed properties (used directly by the View)

    /// Greeting based on the current hour of the day
    var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default:      return "Good night"
        }
    }

    /// Formatted date string, e.g. "Friday, July 11"
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"  // EEEE = full weekday, MMMM = full month
        return formatter.string(from: .now)
    }

    /// True if there's a trip planned for today
    var hasTripToday: Bool {
        currentTrip?.isToday == true && currentTrip?.stops.isEmpty == false
    }

    // MARK: - Intent functions (actions the View can trigger)

    /// Called when the user taps "Plan Your Day"
    func startPlanningTrip() {
        isShowingTripBuilder = true
    }

    /// Called by TripBuilderView (FR3) when it creates a trip.
    /// Saves to history so it persists across app restarts.
    func setTrip(_ trip: Trip) {
        currentTrip = trip
        TripHistoryService.shared.save(trip)   // persist to disk immediately
    }

    /// Called when the user wants to clear/delete the current trip.
    /// Keeps the trip in history — just removes it from "today".
    func clearTrip() {
        currentTrip = nil
    }
}
