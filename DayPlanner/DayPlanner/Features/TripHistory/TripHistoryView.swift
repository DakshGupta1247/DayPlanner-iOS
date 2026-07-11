//
//  TripHistoryView.swift
//  DayPlanner
//
//  Shows all saved trips grouped into "Today / This Week / Earlier".
//  The user can tap a trip to view its summary, or swipe-to-delete it.
//
//  Key SwiftUI concept — List sections:
//  SwiftUI's List natively supports sections with headers. We use our
//  ViewModel's `groupedTrips` — an array of (title, [Trip]) tuples —
//  to drive one Section per group.
//

import SwiftUI

struct TripHistoryView: View {

    @State private var viewModel = TripHistoryViewModel()

    // When the user taps a trip card we push TripDetailView onto the stack
    @State private var selectedTrip: Trip? = nil

    var body: some View {
        Group {
            if viewModel.trips.isEmpty {
                emptyState
            } else {
                tripList
            }
        }
        .navigationTitle("Trip History")
        .navigationBarTitleDisplayMode(.large)
        // Load trips every time this screen appears (handles deletions etc.)
        .onAppear { viewModel.loadTrips() }
        .navigationDestination(item: $selectedTrip) { trip in
            TripDetailView(trip: trip)
        }
    }

    // MARK: - Trip List

    @ViewBuilder
    private var tripList: some View {
        List {
            ForEach(viewModel.groupedTrips, id: \.title) { group in
                Section(header: Text(group.title).font(.caption.bold())) {
                    ForEach(group.trips) { trip in
                        TripHistoryRow(trip: trip)
                            .contentShape(Rectangle())  // makes whole row tappable
                            .onTapGesture { selectedTrip = trip }
                            // swipe-left to delete
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    viewModel.delete(tripID: trip.id)
                                } label: {
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
                .font(.system(size: 60, weight: .light))
                .foregroundStyle(.secondary)
            Text("No trips yet")
                .font(.title3.bold())
            Text("Trips you plan will be saved here automatically.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Trip History Row

/// One row in the history list — shows name, date, stop count, travel mode.
private struct TripHistoryRow: View {
    let trip: Trip

    var body: some View {
        HStack(spacing: 14) {

            // Date badge — day number + short month
            VStack(spacing: 2) {
                Text(trip.date.formatted(.dateTime.day()))
                    .font(.title2.bold())
                Text(trip.date.formatted(.dateTime.month(.abbreviated)))
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
            }
            .frame(width: 44)

            Divider().frame(height: 40)

            // Trip details
            VStack(alignment: .leading, spacing: 3) {
                Text(trip.name)
                    .font(.subheadline.bold())
                    .lineLimit(1)

                HStack(spacing: 8) {
                    // Stop count
                    Label("\(trip.stops.count) stops", systemImage: "mappin.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Total planned time
                    Label(formattedDuration, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Travel mode icon
            Image(systemName: trip.travelMode.symbolName)
                .font(.caption)
                .foregroundStyle(.blue)
                .padding(8)
                .background(.blue.opacity(0.1))
                .clipShape(Circle())
        }
        .padding(.vertical, 4)
    }

    private var formattedDuration: String {
        let total = trip.totalMinutesToSpend
        let hours = total / 60
        let mins  = total % 60
        if hours > 0 { return "\(hours)h \(mins)m" }
        return "\(mins) min"
    }
}

// MARK: - Trip Detail View

/// Pushed when the user taps a history row — shows the full TripSummaryCard
/// plus the stop list, so the user can review a past trip.
struct TripDetailView: View {
    let trip: Trip

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Reuse the same card from the Home screen
                TripSummaryCard(trip: trip)

                Text("Stops")
                    .font(.headline)
                    .padding(.horizontal, 20)

                VStack(spacing: 12) {
                    ForEach(Array(trip.stops.enumerated()), id: \.element.id) { index, stop in
                        StopDetailRow(number: index + 1, stop: stop)
                    }
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 32)
            }
            .padding(.top, 16)
        }
        .navigationTitle(trip.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Stop Detail Row

private struct StopDetailRow: View {
    let number: Int
    let stop: Stop

    var body: some View {
        HStack(spacing: 12) {
            // Number badge
            ZStack {
                Circle().fill(.blue).frame(width: 28, height: 28)
                Text("\(number)").font(.caption.bold()).foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(stop.name).font(.subheadline.bold()).lineLimit(1)
                Text(stop.address).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }

            Spacer()

            Text("\(stop.minutesToSpend) min")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

#Preview {
    NavigationStack {
        TripHistoryView()
    }
}
