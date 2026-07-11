//
//  NavigationView.swift
//  DayPlanner
//
//  The "Start Trip" screen — guides the user through each stop one at a time.
//
//  Layout:
//  - Top: progress bar + stop counter
//  - Middle: mini map centered on the current stop
//  - Current stop card with "Navigate in Maps" + "I've Arrived" buttons
//  - Expandable steps sheet (in-app directions preview)
//  - Remaining stops list at the bottom
//  - Completion screen when all stops are visited
//

import MapKit
import SwiftUI

struct NavigationView: View {

    @State private var viewModel: NavigationViewModel
    @Environment(\.dismiss) private var dismiss

    init(trip: Trip, route: ComputedRoute) {
        _viewModel = State(initialValue: NavigationViewModel(trip: trip, route: route))
    }

    var body: some View {
        Group {
            if viewModel.tripComplete {
                TripCompleteView(trip: viewModel.trip, onDismiss: { dismiss() })
            } else {
                activeNavigationView
            }
        }
        .navigationTitle("Navigation")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel.tripComplete)
    }

    // MARK: - Active Navigation

    private var activeNavigationView: some View {
        ScrollView {
            VStack(spacing: 16) {

                // — Progress header —
                ProgressHeader(viewModel: viewModel)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                // — Mini map centered on current stop —
                if let stop = viewModel.currentStop {
                    CurrentStopMap(stop: stop)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal, 16)
                }

                // — Current stop card —
                if let stop = viewModel.currentStop {
                    CurrentStopCard(
                        stop: stop,
                        stopLabel: viewModel.stopCountLabel,
                        onNavigate: { viewModel.navigateInMaps() },
                        onArrived: { viewModel.markCurrentStopArrived() }
                    )
                    .padding(.horizontal, 16)
                }

                // — In-app steps section —
                StepsSection(viewModel: viewModel)
                    .padding(.horizontal, 16)

                // — Remaining stops —
                if !viewModel.remainingStops.dropFirst().isEmpty {
                    RemainingStopsSection(
                        stops: Array(viewModel.remainingStops.dropFirst())
                    )
                    .padding(.horizontal, 16)
                }

                // — Completed stops (greyed) —
                if !viewModel.completedStops.isEmpty {
                    CompletedStopsSection(stops: viewModel.completedStops)
                        .padding(.horizontal, 16)
                }

                Spacer(minLength: 32)
            }
        }
    }
}

// MARK: - Progress Header

private struct ProgressHeader: View {
    let viewModel: NavigationViewModel

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Stop \(viewModel.stopCountLabel)")
                    .font(.subheadline.bold())
                Spacer()
                Text(viewModel.trip.travelMode.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Image(systemName: viewModel.trip.travelMode.symbolName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Segmented progress bar — one segment per stop
            HStack(spacing: 4) {
                ForEach(Array(viewModel.stops.enumerated()), id: \.element.id) { index, _ in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(index < viewModel.currentStopIndex ? Color.green :
                              index == viewModel.currentStopIndex ? Color.blue : Color.gray.opacity(0.25))
                        .frame(height: 6)
                        .animation(.easeInOut(duration: 0.3), value: viewModel.currentStopIndex)
                }
            }
        }
    }
}

// MARK: - Current Stop Map

/// Mini map pinned to the current stop with a large annotation.
private struct CurrentStopMap: View {
    let stop: Stop

    var body: some View {
        Map(position: .constant(.region(MKCoordinateRegion(
            center: stop.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )))) {
            Annotation(stop.name, coordinate: stop.coordinate) {
                ZStack {
                    Circle().fill(.blue).frame(width: 36, height: 36).shadow(radius: 4)
                    Image(systemName: "mappin.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .mapControlVisibility(.hidden) // hide zoom/compass buttons in the mini map
    }
}

// MARK: - Current Stop Card

private struct CurrentStopCard: View {
    let stop: Stop
    let stopLabel: String
    let onNavigate: () -> Void
    let onArrived: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Stop info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Next Stop")
                        .font(.caption.bold())
                        .foregroundStyle(.blue)
                        .textCase(.uppercase)
                    Spacer()
                    Text(stopLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(stop.name)
                    .font(.title3.bold())
                Text(stop.address)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Divider()

            // Action buttons
            HStack(spacing: 12) {

                // Opens Apple Maps — primary action
                Button(action: onNavigate) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                        Text("Navigate")
                    }
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                // Mark arrived — advances to next stop
                Button(action: onArrived) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Arrived")
                    }
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(.green.opacity(0.15))
                    .foregroundStyle(.green)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.07), radius: 10, y: 2)
    }
}

// MARK: - Steps Section

/// Collapsible in-app directions panel.
private struct StepsSection: View {
    let viewModel: NavigationViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header / toggle
            Button {
                viewModel.isShowingSteps.toggle()
                if viewModel.isShowingSteps && viewModel.steps.isEmpty {
                    Task { await viewModel.fetchStepsForCurrentLeg() }
                }
            } label: {
                HStack {
                    Image(systemName: "list.number")
                        .foregroundStyle(.blue)
                    Text("Step-by-step directions")
                        .font(.subheadline.bold())
                    Spacer()
                    Image(systemName: viewModel.isShowingSteps ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            if viewModel.isShowingSteps {
                Divider()

                if viewModel.isLoadingSteps {
                    HStack {
                        Spacer()
                        ProgressView("Loading directions...")
                            .padding()
                        Spacer()
                    }
                } else if let error = viewModel.stepError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(14)
                } else if viewModel.steps.isEmpty {
                    Text("Open the first stop in Maps to begin.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(14)
                } else {
                    // List of step rows
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.steps.enumerated()), id: \.element.id) { index, step in
                            StepRow(index: index + 1, step: step)
                            if index < viewModel.steps.count - 1 { Divider() }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct StepRow: View {
    let index: Int
    let step: NavigationStep

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index)")
                .font(.caption2.bold())
                .frame(width: 20, height: 20)
                .background(Color.blue.opacity(0.15))
                .foregroundStyle(.blue)
                .clipShape(Circle())
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(step.instruction)
                    .font(.subheadline)
                Text(step.formattedDistance)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Remaining Stops

private struct RemainingStopsSection: View {
    let stops: [Stop]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Up Next")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Color.blue.opacity(0.12)).frame(width: 32, height: 32)
                        Text("\(index + 2)")
                            .font(.caption.bold()).foregroundStyle(.blue)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stop.name).font(.subheadline.bold()).lineLimit(1)
                        Text(stop.address).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Text("\(stop.minutesToSpend) min")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

// MARK: - Completed Stops

private struct CompletedStopsSection: View {
    let stops: [Stop]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Visited")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ForEach(stops) { stop in
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title3)
                    Text(stop.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .strikethrough(true, color: .secondary)
                    Spacer()
                }
                .padding(.horizontal, 4)
            }
        }
    }
}

// MARK: - Trip Complete

private struct TripCompleteView: View {
    let trip: Trip
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Celebration illustration
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 160, height: 160)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.green)
            }

            VStack(spacing: 8) {
                Text("Trip Complete!")
                    .font(.title.bold())
                Text("You visited all \(trip.stops.count) stops on \(trip.name).")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button(action: onDismiss) {
                Text("Back to Home")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }
}

#Preview {
    NavigationStack {
        NavigationView(
            trip: Trip(
                name: "SF Day Out",
                date: .now,
                stops: [
                    Stop(name: "Ferry Building", address: "1 Ferry Building, SF",
                         latitude: 37.7955, longitude: -122.3937, minutesToSpend: 45),
                    Stop(name: "Golden Gate Park", address: "Golden Gate Park, SF",
                         latitude: 37.7694, longitude: -122.4862, minutesToSpend: 90)
                ],
                travelMode: .driving
            ),
            route: ComputedRoute(
                orderedStops: [
                    Stop(name: "Ferry Building", address: "1 Ferry Building, SF",
                         latitude: 37.7955, longitude: -122.3937, minutesToSpend: 45),
                    Stop(name: "Golden Gate Park", address: "Golden Gate Park, SF",
                         latitude: 37.7694, longitude: -122.4862, minutesToSpend: 90)
                ],
                legs: [
                    RouteLeg(
                        from: Stop(name: "Ferry Building", address: "", latitude: 37.7955,
                                   longitude: -122.3937, minutesToSpend: 45),
                        to:   Stop(name: "Golden Gate Park", address: "", latitude: 37.7694,
                                   longitude: -122.4862, minutesToSpend: 90),
                        distanceMeters: 8200, travelTimeSeconds: 780,
                        polyline: MKPolyline()
                    )
                ],
                totalDistanceMeters: 8200,
                totalTravelTimeSeconds: 780
            )
        )
    }
}
