//
//  HomeViewModel.swift
//  DayPlanner (PlanDay)
//
//  Home screen ViewModel — owns the full list of PlanItems and exposes
//  today's focus item plus the full sorted list for the "All Plans" section.
//

import Foundation
import Observation
import SwiftUI

@Observable
final class HomeViewModel {

    // Full list of all saved plans (both DayPlans and Trips)
    var items: [PlanItem] = []

    // FAB menu open/close
    var isFABMenuOpen = false

    // Create-mode builder sheets
    var showingDayPlanBuilder = false
    var showingTripBuilder    = false

    // Edit-mode: which plan is being edited (nil = not editing)
    var editingDayPlan: DayPlan? = nil
    var editingTrip: Trip? = nil

    // Delete confirmation
    var itemPendingDelete: PlanItem? = nil

    init() {
        items = TripHistoryService.shared.loadAll()
    }

    // MARK: - Computed

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default:      return "Good night"
        }
    }

    var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: .now)
    }

    /// The plan that is active today — shown in the "Today's Focus" banner
    var todaysItem: PlanItem? {
        items.first { $0.status == .active }
    }

    /// All plans sorted newest-first for the "All Plans" list
    var sortedItems: [PlanItem] {
        items.sorted { $0.startDate > $1.startDate }
    }

    // MARK: - Intents

    func saveDayPlan(_ plan: DayPlan) {
        let item = PlanItem.singleDay(plan)
        TripHistoryService.shared.save(item)
        // Schedule (or update) a reminder notification for this plan.
        Task { await NotificationService.shared.scheduleReminder(for: item) }
        reload()
    }

    func saveTrip(_ trip: Trip) {
        let item = PlanItem.multiDayTrip(trip)
        TripHistoryService.shared.save(item)
        // Schedule (or update) a reminder notification for this trip.
        Task { await NotificationService.shared.scheduleReminder(for: item) }
        reload()
    }

    func delete(_ item: PlanItem) {
        // Cancel the pending notification before removing the plan.
        NotificationService.shared.cancelReminder(for: item.id)
        TripHistoryService.shared.delete(id: item.id)
        reload()
    }

    func reload() {
        items = TripHistoryService.shared.loadAll()
    }

    func toggleFAB() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isFABMenuOpen.toggle()
        }
    }

    // MARK: - Edit helpers

    func startEditing(_ item: PlanItem) {
        isFABMenuOpen = false
        switch item {
        case .singleDay(let plan): editingDayPlan = plan
        case .multiDayTrip(let trip): editingTrip = trip
        }
    }
}
