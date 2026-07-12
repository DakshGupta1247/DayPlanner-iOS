//
//  TripSummaryCard.swift
//  DayPlanner (PlanDay)
//
//  Reusable summary card — now accepts a DayPlan.
//  Used by ItineraryView header and any other screen needing a compact plan summary.
//

import SwiftUI

struct TripSummaryCard: View {
    let dayPlan: DayPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dayPlan.name).font(.headline)
                    Text(dayPlan.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Label(dayPlan.travelMode.rawValue, systemImage: dayPlan.travelMode.symbolName)
                    .font(.caption.bold())
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(.blue.opacity(0.12)).foregroundStyle(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            Divider()
            HStack(spacing: 0) {
                StatPill(value: "\(dayPlan.stops.count)",
                         label: dayPlan.stops.count == 1 ? "Stop" : "Stops",
                         symbol: "mappin.circle.fill", color: .blue)
                Divider().frame(height: 36)
                StatPill(value: formattedDuration(dayPlan.totalMinutesToSpend),
                         label: "Planned", symbol: "clock.fill", color: .orange)
                Divider().frame(height: 36)
                StatPill(value: dayPlan.status.label,
                         label: dayPlan.startTime.formatted(.dateTime.hour().minute()),
                         symbol: dayPlan.status.symbolName, color: .green)
            }
        }
        .padding(20)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.07), radius: 12, x: 0, y: 4)
    }

    private func formattedDuration(_ m: Int) -> String {
        guard m > 0 else { return "—" }
        let h = m / 60; let mins = m % 60
        if h > 0 && mins > 0 { return "\(h)h \(mins)m" }
        return h > 0 ? "\(h)h" : "\(mins)m"
    }
}

private struct StatPill: View {
    let value: String; let label: String; let symbol: String; let color: Color
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: symbol).font(.caption).foregroundStyle(color)
            Text(value).font(.subheadline.bold())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    TripSummaryCard(dayPlan: DayPlan(
        name: "Saturday Adventure",
        date: .now,
        stops: [
            Stop(name: "Coffee Shop", address: "123 Main St", latitude: 0, longitude: 0, minutesToSpend: 30),
            Stop(name: "Museum", address: "456 Park Ave", latitude: 0, longitude: 0, minutesToSpend: 90)
        ],
        travelMode: .driving
    ))
    .padding()
}
