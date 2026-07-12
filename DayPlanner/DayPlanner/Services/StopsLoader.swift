//
//  StopsLoader.swift
//  DayPlanner
//
//  Decodes stops.json from the app bundle into Stop instances.
//  openUntil "HH:mm" strings are converted to today's Date for ETAEngine.
//

import Foundation

struct StopsLoader {

    static func loadBundledStops() -> [Stop] {
        guard let url = Bundle.main.url(forResource: "stops", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode([RawStop].self, from: data)
        else { return [] }

        return raw.map { $0.toStop() }
    }

    // MARK: - Private decoding types

    private struct RawStop: Decodable {
        let id: String
        let name: String
        let coordinate: Coordinate
        let openUntil: String?

        struct Coordinate: Decodable {
            let lat: Double
            let lng: Double
        }

        func toStop() -> Stop {
            var stop = Stop(
                name: name,
                address: name,      // no address field in JSON — use name as fallback
                latitude: coordinate.lat,
                longitude: coordinate.lng,
                minutesToSpend: 60
            )
            stop.openUntil = openUntil.flatMap { Self.parseTime($0) }
            return stop
        }

        /// Parses "HH:mm" into today's Date at that wall-clock time.
        private static func parseTime(_ string: String) -> Date? {
            let parts = string.split(separator: ":").compactMap { Int($0) }
            guard parts.count == 2 else { return nil }
            var components = Calendar.current.dateComponents([.year, .month, .day], from: .now)
            components.hour   = parts[0]
            components.minute = parts[1]
            components.second = 0
            return Calendar.current.date(from: components)
        }
    }
}
