//
//  TripHistoryService.swift
//  DayPlanner (PlanDay)
//
//  Saves and loads [PlanItem] (both standalone DayPlans and multi-day Trips)
//  as a single JSON file.
//
//  Migration: old JSON was [Trip] with a flat `date`+`stops` shape.
//  We try the new format first; if that fails we attempt the old format
//  and silently convert each old Trip into a PlanItem.singleDay(DayPlan).
//

import Foundation

final class TripHistoryService {

    static let shared = TripHistoryService()
    private init() {}

    // MARK: - File location

    private var fileURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("plan_history.json")
    }

    // MARK: - Public API

    func save(_ item: PlanItem) {
        var all = loadAll()
        if let index = all.firstIndex(where: { $0.id == item.id }) {
            all[index] = item
        } else {
            all.append(item)
        }
        write(all)
    }

    func loadAll() -> [PlanItem] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }

        // Try new format first
        if let items = try? JSONDecoder().decode([PlanItem].self, from: data) {
            return items.sorted { $0.startDate > $1.startDate }
        }

        // Fall back: old format was [Trip] with date + stops at top level
        if let oldTrips = try? JSONDecoder().decode([LegacyTrip].self, from: data) {
            return oldTrips
                .map { PlanItem.singleDay(DayPlan(
                    id: $0.id,
                    name: $0.name,
                    date: $0.date,
                    stops: $0.stops,
                    travelMode: $0.travelMode
                ))}
                .sorted { $0.startDate > $1.startDate }
        }

        return []
    }

    func delete(id: UUID) {
        var all = loadAll()
        all.removeAll { $0.id == id }
        write(all)
    }

    /// Returns the plan item that is active today, if any
    func loadTodaysItem() -> PlanItem? {
        loadAll().first { $0.status == .active }
    }

    // MARK: - Private

    private func write(_ items: [PlanItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

// MARK: - Legacy migration struct

/// Mirrors the old Trip JSON shape (date + stops at top level) for backward compat.
private struct LegacyTrip: Codable {
    let id: UUID
    var name: String
    var date: Date
    var stops: [Stop]
    var travelMode: TravelMode
}
