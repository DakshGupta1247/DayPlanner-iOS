//
//  TripDetailView.swift
//  DayPlanner (PlanDay)
//
//  Pushed when the user taps "View Trip" on a Trip Card.
//  Shows all days as tappable Day Cards — each one navigates into
//  the route / itinerary for that day.
//

import SwiftUI

struct TripDetailView: View {
    let trip: Trip

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Trip header
                TripHeader(trip: trip)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                // Day list
                VStack(spacing: 12) {
                    ForEach(Array(trip.days.enumerated()), id: \.element.id) { index, day in
                        DayRowCard(dayNumber: index + 1, day: day)
                            .padding(.horizontal, 16)
                    }
                }

                Spacer(minLength: 32)
            }
        }
        .navigationTitle(trip.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Trip Header

private struct TripHeader: View {
    let trip: Trip

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.hex( trip.coverColor).opacity(0.15))
                    .frame(width: 60, height: 60)
                Text(trip.emoji).font(.largeTitle)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(trip.name).font(.title2.bold())
                Text(trip.dateRangeLabel).font(.subheadline).foregroundStyle(.secondary)
                Text(trip.summaryLabel).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(Color.hex( trip.coverColor).opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

// MARK: - Day Row Card

private struct DayRowCard: View {
    let dayNumber: Int
    let day: DayPlan

    @State private var showingRoute = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Day \(dayNumber)")
                        .font(.caption.bold()).foregroundStyle(.blue).textCase(.uppercase)
                    Text(day.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                        .font(.subheadline.bold())
                }
                Spacer()
                StatusBadge(status: day.status)
            }

            if day.stops.isEmpty {
                Text("No stops added yet")
                    .font(.caption).foregroundStyle(.secondary).italic()
            } else {
                // First 3 stops as a preview
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(day.stops.prefix(3).enumerated()), id: \.element.id) { i, stop in
                        HStack(spacing: 8) {
                            Circle().fill(.blue).frame(width: 6, height: 6)
                            Text(stop.name).font(.caption).lineLimit(1)
                        }
                    }
                    if day.stops.count > 3 {
                        Text("+\(day.stops.count - 3) more")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .padding(.leading, 4)

                HStack(spacing: 10) {
                    Label("\(day.stops.count) stops", systemImage: "mappin.circle")
                    Label(formattedDuration(day.totalMinutesToSpend), systemImage: "clock")
                }
                .font(.caption).foregroundStyle(.secondary)

                Button { showingRoute = true } label: {
                    Label("View Day Route", systemImage: "map")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(14)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        .navigationDestination(isPresented: $showingRoute) {
            RouteOptimizerView(dayPlan: day)
        }
    }

    private func formattedDuration(_ m: Int) -> String {
        guard m > 0 else { return "—" }
        let h = m / 60; let mins = m % 60
        if h > 0 && mins > 0 { return "\(h)h \(mins)m" }
        return h > 0 ? "\(h)h" : "\(mins)m"
    }
}

// MARK: - Status Badge (re-exported for TripDetailView file)

private struct StatusBadge: View {
    let status: PlanStatus
    private var color: Color {
        switch status {
        case .active: return .blue; case .upcoming: return .orange; case .completed: return .green
        }
    }
    var body: some View {
        Label(status.label, systemImage: status.symbolName)
            .font(.caption2.bold())
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(color.opacity(0.12)).foregroundStyle(color)
            .clipShape(Capsule())
    }
}
