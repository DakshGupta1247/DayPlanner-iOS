//
//  Trip.swift
//  DayPlanner (PlanDay)
//
//  Stop, Trip, and TravelMode — the core data structures.
//
//  Trip now wraps an array of DayPlans (days) plus display metadata:
//  emoji and coverColor are user-picked at creation time.
//  status is auto-derived (no stored value).
//

import Foundation
import CoreLocation

// MARK: - Stop

struct Stop: Identifiable, Codable, Hashable {

    let id: UUID
    var name: String
    var address: String
    var latitude: Double
    var longitude: Double
    var minutesToSpend: Int
    // Transient flag — not persisted to disk (excluded from Codable via custom keys)
    var isVisited: Bool = false

    nonisolated var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(id: UUID = UUID(), name: String, address: String,
         latitude: Double, longitude: Double, minutesToSpend: Int = 30) {
        self.id = id
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.minutesToSpend = minutesToSpend
    }

    // Exclude isVisited from Codable so existing JSON never breaks
    enum CodingKeys: String, CodingKey {
        case id, name, address, latitude, longitude, minutesToSpend
    }
}

// MARK: - Trip

/// A multi-day trip — a named container of DayPlans.
struct Trip: Identifiable, Codable, Hashable {

    let id: UUID
    var name: String        // e.g. "Goa Trip 🌴"
    var emoji: String       // single emoji chosen by user, e.g. "🗺️"
    var coverColor: String  // hex string, e.g. "#3B82F6"
    var days: [DayPlan]     // one DayPlan per day, in date order

    // MARK: - Computed

    var startDate: Date   { days.first?.date ?? .now }
    var endDate: Date     { days.last?.date  ?? .now }
    var totalStops: Int   { days.reduce(0) { $0 + $1.stops.count } }
    var isMultiDay: Bool  { days.count > 1 }

    /// All stops across all days — used by RouteService and Navigation
    var stops: [Stop]     { days.flatMap(\.stops) }

    var travelMode: TravelMode { days.first?.travelMode ?? .driving }

    var totalMinutesToSpend: Int { days.reduce(0) { $0 + $1.totalMinutesToSpend } }

    /// Auto-derived: active if any day is today, completed if last day passed, else upcoming
    var status: PlanStatus {
        if days.contains(where: { $0.isToday }) { return .active }
        if let last = days.last, last.date < Calendar.current.startOfDay(for: .now) {
            return .completed
        }
        return .upcoming
    }

    var isToday: Bool { status == .active }

    /// "Jul 12" for single-day, "Jul 12 – Jul 14" for multi-day
    var dateRangeLabel: String {
        let fmt = Date.FormatStyle().month(.abbreviated).day()
        guard isMultiDay else { return startDate.formatted(fmt) }
        return "\(startDate.formatted(fmt)) – \(endDate.formatted(fmt))"
    }

    /// "3 Days · 12 Stops"
    var summaryLabel: String {
        let d = days.count
        let s = totalStops
        return "\(d) Day\(d == 1 ? "" : "s") · \(s) Stop\(s == 1 ? "" : "s")"
    }

    // MARK: - Init

    init(id: UUID = UUID(), name: String = "My Trip",
         emoji: String = "🗺️", coverColor: String = "#3B82F6",
         days: [DayPlan] = []) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.coverColor = coverColor
        self.days = days
    }

    /// Convenience single-day init — keeps old call sites working
    init(id: UUID = UUID(), name: String = "My Day Trip",
         date: Date = .now, stops: [Stop] = [], travelMode: TravelMode = .driving) {
        self.id = id
        self.name = name
        self.emoji = "🗺️"
        self.coverColor = "#3B82F6"
        self.days = [DayPlan(name: name, date: date, stops: stops, travelMode: travelMode)]
    }
}

// MARK: - TravelMode

enum TravelMode: String, Codable, CaseIterable {
    case driving  = "Driving"
    case walking  = "Walking"
    case transit  = "Transit"

    var symbolName: String {
        switch self {
        case .driving: return "car.fill"
        case .walking: return "figure.walk"
        case .transit: return "tram.fill"
        }
    }
}
