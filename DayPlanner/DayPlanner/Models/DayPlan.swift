//
//  DayPlan.swift
//  DayPlanner (PlanDay)
//
//  The atomic unit of planning — one day's stops, date, and travel mode.
//  Used for both standalone "Day Plan Cards" and days inside a multi-day Trip.
//
//  PlanStatus lives here since it applies to both DayPlan and Trip.
//

import Foundation

// MARK: - PlanStatus

/// Auto-derived from the plan's date — no user action required.
enum PlanStatus: String, Codable, Equatable {
    case upcoming   // date is in the future
    case active     // date is today
    case completed  // date is in the past

    var label: String {
        switch self {
        case .upcoming:  return "Upcoming"
        case .active:    return "Today"
        case .completed: return "Completed"
        }
    }

    var symbolName: String {
        switch self {
        case .upcoming:  return "clock"
        case .active:    return "location.fill"
        case .completed: return "checkmark.circle.fill"
        }
    }
}

// MARK: - DayPlan

/// One day's plan — contains stops, a date, and a start time.
struct DayPlan: Identifiable, Codable, Hashable {

    let id: UUID
    var name: String          // e.g. "Saturday Adventure" or "Day 1"
    var date: Date
    var startTime: Date       // when the user plans to begin the day
    var stops: [Stop]
    var travelMode: TravelMode
    // Set to true when all stops are marked arrived in LiveNavigation.
    // Overrides the date-derived status so the card greys out on the home screen.
    // Reset to false whenever the plan is re-saved through the builder (edit adds new stops).
    var isManuallyCompleted: Bool = false

    // MARK: - Computed

    var totalMinutesToSpend: Int {
        stops.reduce(0) { $0 + $1.minutesToSpend }
    }

    /// Status: manual completion takes priority, then date-derived
    var status: PlanStatus {
        if isManuallyCompleted { return .completed }
        if Calendar.current.isDateInToday(date) { return .active }
        return date > .now ? .upcoming : .completed
    }

    var isToday: Bool { Calendar.current.isDateInToday(date) }

    // MARK: - Init

    init(id: UUID = UUID(), name: String = "Day Plan",
         date: Date = .now, startTime: Date? = nil,
         stops: [Stop] = [], travelMode: TravelMode = .driving) {
        self.id = id
        self.name = name
        self.date = date
        // Default start time: 9:00 AM on the plan's date
        if let t = startTime {
            self.startTime = t
        } else {
            var c = Calendar.current.dateComponents([.year, .month, .day], from: date)
            c.hour = 9; c.minute = 0
            self.startTime = Calendar.current.date(from: c) ?? date
        }
        self.stops = stops
        self.travelMode = travelMode
    }
}
