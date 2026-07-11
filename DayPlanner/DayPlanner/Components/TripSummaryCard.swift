//
//  TripSummaryCard.swift
//  DayPlanner
//
//  A reusable card component that shows a trip's key stats at a glance.
//  Used on the Home screen today, and will also appear in Trip History (FR7).
//
//  Why a separate file?
//  This is a "component" — a small, self-contained UI piece that can be
//  dropped into any view. Keeping it separate means we never duplicate code.
//

import SwiftUI

struct TripSummaryCard: View {

    // The trip to display — passed in by whoever uses this card
    let trip: Trip

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // — Card header: trip name + travel mode icon —
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.name)
                        .font(.headline)
                    Text(trip.date.formatted(date: .long, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Travel mode badge — icon in a small rounded rectangle
                Label(trip.travelMode.rawValue, systemImage: trip.travelMode.symbolName)
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.blue.opacity(0.12))
                    .foregroundStyle(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Divider()

            // — Three stat pills: stops, time to spend, status —
            HStack(spacing: 0) {
                StatPill(
                    value: "\(trip.stops.count)",
                    label: trip.stops.count == 1 ? "Stop" : "Stops",
                    symbol: "mappin.circle.fill",
                    color: .blue
                )

                Divider().frame(height: 36)

                StatPill(
                    value: formattedDuration(trip.totalMinutesToSpend),
                    label: "Planned",
                    symbol: "clock.fill",
                    color: .orange
                )

                Divider().frame(height: 36)

                StatPill(
                    value: trip.isToday ? "Today" : "Upcoming",
                    label: trip.date.formatted(.dateTime.weekday(.wide)),
                    symbol: "calendar",
                    color: .green
                )
            }
        }
        .padding(20)
        .background(.regularMaterial)         // frosted glass effect
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.07), radius: 12, x: 0, y: 4)
    }

    // Converts raw minutes into a readable string: "2h 30m" or "45m"
    private func formattedDuration(_ minutes: Int) -> String {
        guard minutes > 0 else { return "—" }
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 && mins > 0 { return "\(hours)h \(mins)m" }
        if hours > 0 { return "\(hours)h" }
        return "\(mins)m"
    }
}

// MARK: - StatPill

/// A small stat display: icon + big value + small label.
/// Private to this file since nothing else uses it directly.
private struct StatPill: View {
    let value: String
    let label: String
    let symbol: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.subheadline.bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview {
    TripSummaryCard(trip: Trip(
        name: "Weekend Explore",
        date: .now,
        stops: [
            Stop(name: "Coffee Shop", address: "123 Main St", latitude: 0, longitude: 0, minutesToSpend: 30),
            Stop(name: "Museum", address: "456 Park Ave", latitude: 0, longitude: 0, minutesToSpend: 90),
            Stop(name: "Restaurant", address: "789 Food St", latitude: 0, longitude: 0, minutesToSpend: 60)
        ],
        travelMode: .driving
    ))
    .padding()
}
