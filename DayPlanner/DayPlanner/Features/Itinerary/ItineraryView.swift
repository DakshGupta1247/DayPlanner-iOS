//
//  ItineraryView.swift
//  DayPlanner
//
//  The Day Itinerary — a vertical scrollable timeline showing every stop
//  with arrival time, time-to-spend, and travel time to the next stop.
//
//  Layout concept:
//  Each row has a left "spine" column (time + connector line) and a right
//  "card" column (stop details). This creates the classic timeline look.
//
//  Key SwiftUI concept — custom layout with HStack + VStack:
//  We build each timeline row manually using fixed-width columns rather
//  than a List, because List adds separators and padding that would break
//  the continuous vertical line effect.
//

import MapKit
import SwiftUI

struct ItineraryView: View {

    @State private var viewModel: ItineraryViewModel

    init(trip: Trip, route: ComputedRoute) {
        _viewModel = State(initialValue: ItineraryViewModel(trip: trip, route: route))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                // — Day summary header —
                DaySummaryHeader(viewModel: viewModel)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 20)

                // — Timeline rows —
                ForEach(Array(viewModel.entries.enumerated()), id: \.element.id) { index, entry in
                    TimelineRow(
                        entry: entry,
                        index: index,
                        totalCount: viewModel.entries.count,
                        onMinutesChanged: { newMinutes in
                            viewModel.updateMinutesToSpend(for: entry, minutes: newMinutes)
                        }
                    )
                }

                // — Footer: finish time —
                if !viewModel.entries.isEmpty {
                    TripFinishRow(finishTime: viewModel.finishTime)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                }
            }
        }
        .navigationTitle("Day Itinerary")
        .navigationBarTitleDisplayMode(.large)
        // Time picker sheet
        .sheet(isPresented: $viewModel.isEditingStartTime) {
            StartTimePicker(startTime: $viewModel.startTime)
        }
    }
}

// MARK: - Day Summary Header

private struct DaySummaryHeader: View {
    let viewModel: ItineraryViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Trip name + date
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.trip.name)
                    .font(.title2.bold())
                Text(viewModel.trip.dateRangeLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Stats row
            HStack(spacing: 16) {
                // Start time — tappable to edit
                Button {
                    viewModel.isEditingStartTime = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text("Start \(viewModel.startTime.formatted(date: .omitted, time: .shortened))")
                            .font(.subheadline.bold())
                        Image(systemName: "pencil")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.blue.opacity(0.1))
                    .foregroundStyle(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // Total duration
                Label(viewModel.totalDuration, systemImage: "hourglass")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Stop count
                Label("\(viewModel.entries.count) stops", systemImage: "mappin.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Timeline Row

/// One stop in the timeline — left spine + right card.
private struct TimelineRow: View {
    let entry: ItineraryEntry
    let index: Int
    let totalCount: Int
    let onMinutesChanged: (Int) -> Void

    @State private var showingDurationPicker = false

    private var isLast: Bool { index == totalCount - 1 }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {

            // — Left spine: time label + circle + vertical line —
            TimeSpine(
                arrivalTime: entry.formattedArrival,
                isFirst: index == 0,
                isLast: isLast,
                color: spineColor
            )
            .frame(width: 80)

            // — Right card: stop details —
            VStack(alignment: .leading, spacing: 0) {
                StopCard(
                    entry: entry,
                    color: spineColor,
                    onEditDuration: { showingDurationPicker = true }
                )
                .padding(.trailing, 16)
                .padding(.bottom, 4)

                // Travel connector to next stop (shown between stops, not after last)
                if !isLast, let travel = entry.formattedTravelToNext,
                   let dist = entry.formattedDistanceToNext {
                    TravelConnector(travel: travel, distance: dist, mode: "car.fill")
                        .padding(.trailing, 16)
                        .padding(.bottom, 4)
                }
            }
        }
        .padding(.horizontal, 20)
        // Duration picker sheet
        .sheet(isPresented: $showingDurationPicker) {
            StopDurationPickerSheet(
                stopName: entry.stop.name,
                currentMinutes: entry.effectiveMinutes,
                onConfirm: onMinutesChanged
            )
        }
    }

    // Colour coding: green for first, red for last, blue for middle
    private var spineColor: Color {
        if index == 0 { return .green }
        if isLast { return .red }
        return .blue
    }
}

// MARK: - Time Spine

/// The left column: time label + coloured circle + vertical connecting line.
private struct TimeSpine: View {
    let arrivalTime: String
    let isFirst: Bool
    let isLast: Bool
    let color: Color

    var body: some View {
        VStack(spacing: 0) {
            // Time label above the dot
            Text(arrivalTime)
                .font(.caption.bold())
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 8)
                .padding(.top, 16)

            // The dot
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 14, height: 14)
                if isFirst || isLast {
                    Circle()
                        .stroke(color, lineWidth: 2)
                        .frame(width: 20, height: 20)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 11)

            // Vertical line below the dot (not shown after last stop)
            if !isLast {
                Rectangle()
                    .fill(Color.secondary.opacity(0.25))
                    .frame(width: 2)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 18)
                    .frame(minHeight: 80)
            }
        }
    }
}

// MARK: - Stop Card

/// The right column card for a single stop.
private struct StopCard: View {
    let entry: ItineraryEntry
    let color: Color
    let onEditDuration: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Stop name
            Text(entry.stop.name)
                .font(.headline)
                .padding(.top, 12)

            // Address
            Text(entry.stop.address)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            // Time range + duration
            HStack(spacing: 8) {
                // Arrival → Departure range
                Label(
                    "\(entry.formattedArrival) – \(entry.formattedDeparture)",
                    systemImage: "clock"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer()

                // Editable duration badge — shows effective minutes (may be overridden)
                Button(action: onEditDuration) {
                    HStack(spacing: 4) {
                        Text("\(entry.effectiveMinutes) min")
                            .font(.caption.bold())
                        Image(systemName: "pencil")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.12))
                    .foregroundStyle(color)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }
}

// MARK: - Travel Connector

/// The little "→ 12 min drive · 3.2 km" row between two stops.
private struct TravelConnector: View {
    let travel: String
    let distance: String
    let mode: String    // SF Symbol name

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: mode)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(travel) · \(distance)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.leading, 4)
        .padding(.vertical, 4)
    }
}

// MARK: - Trip Finish Row

/// The final row showing the projected end time.
private struct TripFinishRow: View {
    let finishTime: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: "flag.checkered")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Trip ends")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                Text("Estimated finish: \(finishTime)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.top, 8)
    }
}

// MARK: - Start Time Picker Sheet

private struct StartTimePicker: View {
    @Binding var startTime: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Choose when your day starts")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // DatePicker in .graphical style shows a wheel — .hourAndMinute
                // shows only the time picker, not the calendar date.
                DatePicker("Start time", selection: $startTime,
                           displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()

                Spacer()
            }
            .padding()
            .navigationTitle("Start Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .bold()
                }
            }
        }
        .presentationDetents([.medium]) // half-height sheet
    }
}

// DurationPickerSheet is now the shared StopDurationPickerSheet in DayPlanBuilderView.swift

#Preview {
    NavigationStack {
        ItineraryView(
            trip: Trip(
                name: "SF Day Out",
                date: .now,
                stops: [
                    Stop(name: "Ferry Building", address: "1 Ferry Building, SF",
                         latitude: 37.7955, longitude: -122.3937, minutesToSpend: 45),
                    Stop(name: "Golden Gate Park", address: "Golden Gate Park, SF",
                         latitude: 37.7694, longitude: -122.4862, minutesToSpend: 90),
                    Stop(name: "Fisherman's Wharf", address: "Beach St, SF",
                         latitude: 37.8080, longitude: -122.4177, minutesToSpend: 60)
                ],
                travelMode: .driving
            ),
            route: ComputedRoute(
                orderedStops: [
                    Stop(name: "Ferry Building", address: "1 Ferry Building, SF",
                         latitude: 37.7955, longitude: -122.3937, minutesToSpend: 45),
                    Stop(name: "Golden Gate Park", address: "Golden Gate Park, SF",
                         latitude: 37.7694, longitude: -122.4862, minutesToSpend: 90),
                    Stop(name: "Fisherman's Wharf", address: "Beach St, SF",
                         latitude: 37.8080, longitude: -122.4177, minutesToSpend: 60)
                ],
                legs: [
                    RouteLeg(from: Stop(name: "Ferry Building", address: "", latitude: 37.7955,
                                       longitude: -122.3937, minutesToSpend: 45),
                             to:   Stop(name: "Golden Gate Park", address: "", latitude: 37.7694,
                                        longitude: -122.4862, minutesToSpend: 90),
                             distanceMeters: 8200, travelTimeSeconds: 780,
                             polyline: MKPolyline()),
                    RouteLeg(from: Stop(name: "Golden Gate Park", address: "", latitude: 37.7694,
                                        longitude: -122.4862, minutesToSpend: 90),
                             to:   Stop(name: "Fisherman's Wharf", address: "", latitude: 37.8080,
                                        longitude: -122.4177, minutesToSpend: 60),
                             distanceMeters: 6100, travelTimeSeconds: 620,
                             polyline: MKPolyline())
                ],
                totalDistanceMeters: 14300,
                totalTravelTimeSeconds: 1400
            )
        )
    }
}
