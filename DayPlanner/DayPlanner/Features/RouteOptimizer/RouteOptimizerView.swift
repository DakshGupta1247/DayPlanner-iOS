//
//  RouteOptimizerView.swift
//  DayPlanner
//
//  Shows the optimized route on a full-screen map with:
//  - A blue polyline connecting all stops in order
//  - Numbered pins for each stop
//  - A bottom sheet card with total distance + travel time
//  - Loading and error states
//
//  Key SwiftUI concepts:
//  - .task modifier: runs an async function when the view appears,
//    and automatically cancels it if the view disappears. Cleaner than
//    .onAppear + Task { }.
//  - MapPolyline: draws a route path directly on a SwiftUI Map.
//  - ZStack: layers the map behind the bottom card.
//

import MapKit
import SwiftUI

struct RouteOptimizerView: View {

    // @State owns the ViewModel — created once, lives as long as this view
    @State private var viewModel: RouteOptimizerViewModel

    @Environment(\.dismiss) private var dismiss

    init(trip: Trip) {
        _viewModel = State(initialValue: RouteOptimizerViewModel(trip: trip))
    }

    var body: some View {
        ZStack(alignment: .bottom) {

            // — Full screen map —
            mapLayer

            // — Bottom card overlay —
            bottomCard
        }
        .navigationTitle("Optimized Route")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.calculateRoute() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                // Disable the refresh button while loading
                .disabled(viewModel.isLoading)
            }
        }
        // .task runs calculateRoute() when view first appears.
        // If the user navigates away, Swift cancels this task automatically.
        .task {
            await viewModel.calculateRoute()
        }
    }

    // MARK: - Map Layer

    @ViewBuilder
    private var mapLayer: some View {
        Map(position: $viewModel.cameraPosition) {

            // Draw the route polyline(s) in blue
            if case .success(let route) = viewModel.routeState {
                ForEach(Array(route.legs.enumerated()), id: \.offset) { _, leg in
                    MapPolyline(leg.polyline)
                        .stroke(.blue, lineWidth: 4)
                }

                // Numbered pins for each stop in optimized order
                ForEach(Array(route.orderedStops.enumerated()), id: \.element.id) { index, stop in
                    Annotation("", coordinate: stop.coordinate) {
                        RouteStopPin(number: index + 1, isFirst: index == 0,
                                     isLast: index == route.orderedStops.count - 1)
                    }
                }

            } else {
                // While loading / on error, still show the original stops
                ForEach(Array(viewModel.trip.stops.enumerated()), id: \.element.id) { index, stop in
                    Annotation("", coordinate: stop.coordinate) {
                        RouteStopPin(number: index + 1, isFirst: index == 0,
                                     isLast: index == viewModel.trip.stops.count - 1)
                    }
                }
            }
        }
        .ignoresSafeArea()  // map fills the full screen including safe areas
    }

    // MARK: - Bottom Card

    @ViewBuilder
    private var bottomCard: some View {
        switch viewModel.routeState {
        case .idle:
            EmptyView()

        case .loading:
            LoadingCard()

        case .success(let route):
            RouteSuccessCard(route: route, trip: viewModel.trip)

        case .failure(let message):
            ErrorCard(message: message) {
                Task { await viewModel.calculateRoute() }
            }
        }
    }
}

// MARK: - Stop Pin

/// Numbered pin — green for first stop, red for last, blue for the rest.
private struct RouteStopPin: View {
    let number: Int
    let isFirst: Bool
    let isLast: Bool

    private var color: Color {
        if isFirst { return .green }
        if isLast  { return .red }
        return .blue
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 32, height: 32)
                .shadow(radius: 3)
            Text("\(number)")
                .font(.caption.bold())
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Loading Card

private struct LoadingCard: View {
    var body: some View {
        HStack(spacing: 14) {
            ProgressView()
                .scaleEffect(1.2)
            VStack(alignment: .leading, spacing: 4) {
                Text("Optimizing route...")
                    .font(.headline)
                Text("Calculating fastest order and distances")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(20)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 10, y: -2)
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
    }
}

// MARK: - Success Card

private struct RouteSuccessCard: View {
    let route: ComputedRoute
    let trip: Trip

    var body: some View {
        VStack(spacing: 0) {

            // Drag indicator
            RoundedRectangle(cornerRadius: 3)
                .fill(.secondary.opacity(0.4))
                .frame(width: 40, height: 4)
                .padding(.top, 12)

            VStack(alignment: .leading, spacing: 16) {

                // — Stats row —
                HStack(spacing: 0) {
                    StatCell(
                        value: route.formattedDistance,
                        label: "Total distance",
                        symbol: "road.lanes",
                        color: .blue
                    )
                    Divider().frame(height: 40)
                    StatCell(
                        value: route.formattedTravelTime,
                        label: "Travel time",
                        symbol: "car.fill",
                        color: .orange
                    )
                    Divider().frame(height: 40)
                    StatCell(
                        value: "\(route.orderedStops.count)",
                        label: "Stops",
                        symbol: "mappin.circle.fill",
                        color: .green
                    )
                }

                Divider()

                // — Optimized stop order list —
                Text("Optimized order")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                VStack(spacing: 8) {
                    ForEach(Array(route.orderedStops.enumerated()), id: \.element.id) { index, stop in
                        OptimizedStopRow(
                            number: index + 1,
                            stop: stop,
                            leg: index < route.legs.count ? route.legs[index] : nil
                        )
                    }
                }

                // — Start Trip button —
                Button {
                    // TODO: wire to FR6 Navigation
                } label: {
                    Label("Start Trip", systemImage: "location.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.12), radius: 16, y: -4)
        .padding(.horizontal, 8)
        .padding(.bottom, 16)
    }
}

// MARK: - Optimized Stop Row

private struct OptimizedStopRow: View {
    let number: Int
    let stop: Stop
    let leg: RouteLeg?   // leg from this stop to the NEXT (nil for last stop)

    var body: some View {
        HStack(spacing: 10) {
            // Number badge
            ZStack {
                Circle().fill(.blue).frame(width: 26, height: 26)
                Text("\(number)").font(.caption2.bold()).foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(stop.name).font(.subheadline.bold()).lineLimit(1)

                // Show travel time to the NEXT stop (not applicable for last)
                if let leg {
                    let mins = Int(leg.travelTimeSeconds / 60)
                    let dist = MKDistanceFormatter().string(fromDistance: leg.distanceMeters)
                    Text("→ \(dist) · \(mins) min drive")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Time to spend at this stop
            Text("\(stop.minutesToSpend) min")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Stat Cell

private struct StatCell: View {
    let value: String
    let label: String
    let symbol: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: symbol).font(.caption).foregroundStyle(color)
            Text(value).font(.subheadline.bold())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Error Card

private struct ErrorCard: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.orange)
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
            Button("Try Again", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
        .padding(20)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 10, y: -2)
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
    }
}

#Preview {
    NavigationStack {
        RouteOptimizerView(trip: Trip(
            name: "SF Day Out",
            date: .now,
            stops: [
                Stop(name: "Ferry Building", address: "1 Ferry Building, SF", latitude: 37.7955, longitude: -122.3937, minutesToSpend: 45),
                Stop(name: "Golden Gate Park", address: "Golden Gate Park, SF", latitude: 37.7694, longitude: -122.4862, minutesToSpend: 90),
                Stop(name: "Fisherman's Wharf", address: "Beach St, SF", latitude: 37.8080, longitude: -122.4177, minutesToSpend: 60)
            ],
            travelMode: .driving
        ))
    }
}
