//
//  TripHistoryViewModel.swift
//  DayPlanner (PlanDay)
//
//  Thin wrapper kept for any remaining references.
//  TripHistoryView now reads TripHistoryService directly.
//

import Foundation
import Observation

@Observable
@MainActor
final class TripHistoryViewModel {
    var items: [PlanItem] = []

    func loadItems() {
        items = TripHistoryService.shared.loadAll()
    }

    func delete(id: UUID) {
        TripHistoryService.shared.delete(id: id)
        items.removeAll { $0.id == id }
    }
}
