//
//  Trip.swift
//  DayPlanner
//
//  Defines the core data structures for the app.
//
//  A "Stop" is one place the user wants to visit.
//  A "Trip" is the full day plan — a collection of stops with metadata.
//
//  Why structs?
//  Swift structs are value types — when you copy one, you get a completely
//  independent copy. This makes state management in SwiftUI much safer and
//  more predictable than using classes.
//
//  Why Identifiable?
//  SwiftUI's List and ForEach need a way to uniquely identify each item
//  so it can animate additions/removals correctly. Conforming to Identifiable
//  (by adding an `id` property) gives SwiftUI that unique key.
//
//  Why Codable?
//  Codable lets Swift automatically convert our structs to/from JSON.
//  We'll use this in FR7 (Trip History) to save and load trips from disk.
//

import Foundation
import CoreLocation  // gives us CLLocationCoordinate2D (lat/lng)

// MARK: - Stop

/// One place the user wants to visit during their day trip.
struct Stop: Identifiable, Codable {

    let id: UUID            // unique identifier, auto-generated
    var name: String        // display name, e.g. "Eiffel Tower"
    var address: String     // human-readable address
    var latitude: Double    // geographic coordinate
    var longitude: Double
    var minutesToSpend: Int // how long the user plans to stay (in minutes)

    // Computed property — converts our stored lat/lng into a CLLocationCoordinate2D
    // which is what MapKit expects. Not stored, just computed on the fly.
    // nonisolated: safe to call from any actor/thread since it only reads value types.
    nonisolated var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    // A default initializer so we can create stops easily
    init(id: UUID = UUID(), name: String, address: String,
         latitude: Double, longitude: Double, minutesToSpend: Int = 30) {
        self.id = id
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.minutesToSpend = minutesToSpend
    }
}

// MARK: - Trip

/// The full day plan — contains an ordered list of stops and metadata.
struct Trip: Identifiable, Codable {

    let id: UUID
    var name: String          // e.g. "Weekend in Paris"
    var date: Date            // the day this trip is planned for
    var stops: [Stop]         // ordered list of stops
    var travelMode: TravelMode

    // Computed: total minutes the user plans to spend across all stops
    var totalMinutesToSpend: Int {
        stops.reduce(0) { $0 + $1.minutesToSpend }
    }

    // Computed: true if this trip is planned for today
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    init(id: UUID = UUID(), name: String = "My Day Trip",
         date: Date = .now, stops: [Stop] = [], travelMode: TravelMode = .driving) {
        self.id = id
        self.name = name
        self.date = date
        self.stops = stops
        self.travelMode = travelMode
    }
}

// MARK: - TravelMode

/// How the user plans to get between stops.
/// Raw string values let Codable serialize these automatically.
enum TravelMode: String, Codable, CaseIterable {
    case driving  = "Driving"
    case walking  = "Walking"
    case transit  = "Transit"

    // SF Symbol name for each mode — used in the UI
    var symbolName: String {
        switch self {
        case .driving: return "car.fill"
        case .walking: return "figure.walk"
        case .transit: return "tram.fill"
        }
    }
}
