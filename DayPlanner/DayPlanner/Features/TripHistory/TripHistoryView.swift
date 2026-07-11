//
//  TripHistoryView.swift
//  DayPlanner (PlanDay)
//
//  Shows all saved PlanItems (DayPlans + Trips) grouped by time.
//  Accessible from Settings; the Home screen is now the primary entry point.
//

import SwiftUI

struct TripHistoryView: View {

    @State private var items: [PlanItem] = []
    @State private var selectedItem: PlanItem? = nil

    var groupedItems: [(title: String, items: [PlanItem])] {
        let cal = Calendar.current
        let today     = cal.startOfDay(for: .now)
        let weekStart = cal.date(byAdding: .day, value: -6, to: today)!

        let todayItems   = items.filter { cal.isDateInToday($0.startDate) }
        let weekItems    = items.filter {
            let d = cal.startOfDay(for: $0.startDate)
            return d >= weekStart && d < today
        }
        let earlierItems = items.filter { cal.startOfDay(for: $0.startDate) < weekStart }

        return [("Today", todayItems), ("This Week", weekItems), ("Earlier", earlierItems)]
            .filter { !$0.items.isEmpty }
    }

    var body: some View {
        Group {
            if items.isEmpty { emptyState }
            else             { itemList  }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { items = TripHistoryService.shared.loadAll() }
    }

    // MARK: - List

    @ViewBuilder
    private var itemList: some View {
        List {
            ForEach(groupedItems, id: \.title) { group in
                Section(header: Text(group.title).font(.caption.bold())) {
                    ForEach(group.items) { item in
                        HistoryRow(item: item)
                            .contentShape(Rectangle())
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { delete(item) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                .font(.system(size: 60, weight: .light)).foregroundStyle(.secondary)
            Text("No plans yet").font(.title3.bold())
            Text("Plans you create will appear here.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
    }

    private func delete(_ item: PlanItem) {
        TripHistoryService.shared.delete(id: item.id)
        items = TripHistoryService.shared.loadAll()
    }
}

// MARK: - History Row

private struct HistoryRow: View {
    let item: PlanItem

    var body: some View {
        HStack(spacing: 14) {

            // Date badge
            VStack(spacing: 2) {
                Text(item.startDate.formatted(.dateTime.day()))
                    .font(.title2.bold())
                Text(item.startDate.formatted(.dateTime.month(.abbreviated)))
                    .font(.caption2.bold()).foregroundStyle(.secondary)
            }
            .frame(width: 44)

            Divider().frame(height: 40)

            // Details
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if case .multiDayTrip(let t) = item { Text(t.emoji) }
                    Text(itemTitle).font(.subheadline.bold()).lineLimit(1)
                }
                Text(itemSubtitle).font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            // Status dot
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 4)
    }

    private var itemTitle: String {
        switch item {
        case .singleDay(let d):    return d.name
        case .multiDayTrip(let t): return t.name
        }
    }

    private var itemSubtitle: String {
        switch item {
        case .singleDay(let d):
            return "\(d.stops.count) stop\(d.stops.count == 1 ? "" : "s") · \(d.travelMode.rawValue)"
        case .multiDayTrip(let t):
            return t.summaryLabel
        }
    }

    private var statusColor: Color {
        switch item.status {
        case .active: return .blue; case .upcoming: return .orange; case .completed: return .green
        }
    }
}

#Preview {
    NavigationStack { TripHistoryView() }
}
