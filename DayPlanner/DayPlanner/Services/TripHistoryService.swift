//
//  TripHistoryService.swift
//  DayPlanner
//
//  Saves and loads the user's trip history to/from disk as a JSON file.
//
//  Why JSON + FileManager instead of SwiftData?
//  Our Trip and Stop models are already Codable (they know how to convert
//  themselves to/from JSON). FileManager lets us write that JSON to the
//  app's private Documents folder — simple, reliable, no extra setup.
//
//  Where is the file stored?
//  iOS gives every app a "sandbox" — a private folder it fully owns.
//  We write to the Documents directory inside that sandbox:
//    /var/mobile/…/Documents/trip_history.json
//  The user can't see this file, but it survives app restarts.
//
//  Why a singleton (shared)?
//  We want exactly one TripHistoryService in the whole app so all reads
//  and writes go through the same object. `static let shared` creates one
//  instance and reuses it everywhere.
//

import Foundation

final class TripHistoryService {

    // The one shared instance — use TripHistoryService.shared everywhere
    static let shared = TripHistoryService()
    private init() {} // private: prevents anyone from calling TripHistoryService()

    // MARK: - File location

    // Builds the path: .../Documents/trip_history.json
    private var fileURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]  // Documents folder
            .appendingPathComponent("trip_history.json")
        }

    // MARK: - Public API

    /// Saves a trip. If a trip with the same id already exists it is replaced;
    /// otherwise the new trip is appended to the end of the history list.
    func save(_ trip: Trip) {
        var all = loadAll()
        if let index = all.firstIndex(where: { $0.id == trip.id }) {
            all[index] = trip   // update in place
        } else {
            all.append(trip)    // add new
        }
        write(all)
    }

    /// Returns all saved trips, newest first.
    func loadAll() -> [Trip] {
        // Try to read the file from disk.
        // If the file doesn't exist yet (first launch) Data(contentsOf:) throws
        // and we return an empty array — no crash, just no history yet.
        guard let data = try? Data(contentsOf: fileURL),
              let trips = try? JSONDecoder().decode([Trip].self, from: data)
        else { return [] }

        return trips.sorted { $0.date > $1.date }   // newest first
    }

    /// Removes the trip with the given id from the history file.
    func delete(tripID: UUID) {
        var all = loadAll()
        all.removeAll { $0.id == tripID }
        write(all)
    }

    /// Returns today's saved trip, if one exists.
    func loadTodaysTrip() -> Trip? {
        loadAll().first { Calendar.current.isDateInToday($0.date) }
    }

    // MARK: - Private helpers

    // Encodes the array to JSON and writes it to disk.
    // .atomic means iOS writes to a temp file first, then renames — so the
    // file is never left half-written if the app crashes mid-write.
    private func write(_ trips: [Trip]) {
        guard let data = try? JSONEncoder().encode(trips) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
