//
//  RouteOptimizerView.swift
//  DayPlanner (PlanDay)
//
//  Shows the optimized route for a single DayPlan on a full-screen map.
//  Takes a DayPlan; ViewModel wraps it in a synthetic Trip for the downstream
//  NavigationView and ItineraryView which still accept Trip.
//

import MapKit
import SwiftUI

struct RouteOptimizerView: View {

    @State private var viewModel: RouteOptimizerViewModel
    @Environment(\.dismiss) private var dismiss

    init(dayPlan: DayPlan) {
        _viewModel = State(initialValue: RouteOptimizerViewModel(dayPlan: dayPlan))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            mapLayer
            bottomCard
        }
        .navigationTitle("Optimized Route")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await viewModel.calculateRoute() } } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
            }
        }
        .task { await viewModel.calculateRoute() }
    }

    // MARK: - Map

    @ViewBuilder
    private var mapLayer: some View {
        Map(position: $viewModel.cameraPosition) {

            if case .success(let route) = viewModel.routeState {
                ForEach(Array(route.legs.enumerated()), id: \.offset) { _, leg in
                    MapPolyline(leg.polyline).stroke(.blue, lineWidth: 4)
                }
                ForEach(Array(route.orderedStops.enumerated()), id: \.element.id) { index, stop in
                    Annotation("", coordinate: stop.coordinate) {
                        RouteStopPin(number: index + 1,
                                     isFirst: index == 0,
                                     isLast: index == route.orderedStops.count - 1)
                    }
                }
            } else {
                ForEach(Array(viewModel.dayPlan.stops.enumerated()), id: \.element.id) { index, stop in
                    Annotation("", coordinate: stop.coordinate) {
                        RouteStopPin(number: index + 1,
                                     isFirst: index == 0,
                                     isLast: index == viewModel.dayPlan.stops.count - 1)
                    }
                }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Bottom card

    @ViewBuilder
    private var bottomCard: some View {
        switch viewModel.routeState {
        case .idle:       EmptyView()
        case .loading:    LoadingCard()
        case .success(let route):
            RouteSuccessCard(route: route, trip: viewModel.trip)
        case .failure(let msg):
            ErrorCard(message: msg) { Task { await viewModel.calculateRoute() } }
        }
    }
}

// MARK: - Route Stop Pin

private struct RouteStopPin: View {
    let number: Int
    let isFirst: Bool
    let isLast: Bool
    private var color: Color { isFirst ? .green : isLast ? .red : .blue }
    var body: some View {
        ZStack {
            Circle().fill(color).frame(width: 32, height: 32).shadow(radius: 3)
            Text("\(number)").font(.caption.bold()).foregroundStyle(.white)
        }
    }
}

// MARK: - Loading Card

private struct LoadingCard: View {
    var body: some View {
        HStack(spacing: 14) {
            ProgressView().scaleEffect(1.2)
            VStack(alignment: .leading, spacing: 4) {
                Text("Optimizing route...").font(.headline)
                Text("Calculating fastest order and distances")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(20)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 10, y: -2)
        .padding(.horizontal, 16).padding(.bottom, 32)
    }
}

// MARK: - Success Card

private struct RouteSuccessCard: View {
    let route: ComputedRoute
    let trip: Trip

    @State private var showingItinerary  = false
    @State private var showingNavigation = false

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3)
                .fill(.secondary.opacity(0.4))
                .frame(width: 40, height: 4)
                .padding(.top, 12)

            VStack(alignment: .leading, spacing: 16) {

                // Stats
                HStack(spacing: 0) {
                    StatCell(value: route.formattedDistance,   label: "Distance",  symbol: "road.lanes",       color: .blue)
                    Divider().frame(height: 40)
                    StatCell(value: route.formattedTravelTime, label: "Travel time", symbol: "car.fill",         color: .orange)
                    Divider().frame(height: 40)
                    StatCell(value: "\(route.orderedStops.count)", label: "Stops",  symbol: "mappin.circle.fill", color: .green)
                }

                Divider()

                // Ordered stop list
                Text("Optimized order")
                    .font(.caption.bold()).foregroundStyle(.secondary).textCase(.uppercase)

                VStack(spacing: 8) {
                    ForEach(Array(route.orderedStops.enumerated()), id: \.element.id) { i, stop in
                        OptimizedStopRow(number: i + 1, stop: stop,
                                         leg: i < route.legs.count ? route.legs[i] : nil)
                    }
                }

                // Action buttons
                HStack(spacing: 12) {
                    Button { showingItinerary = true } label: {
                        Label("Itinerary", systemImage: "list.bullet.rectangle")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.blue.opacity(0.1))
                            .foregroundStyle(.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    Button { showingNavigation = true } label: {
                        Label("Start Day", systemImage: "location.fill")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .navigationDestination(isPresented: $showingItinerary) {
                    ItineraryView(trip: trip, route: route)
                }
                .navigationDestination(isPresented: $showingNavigation) {
                    NavigationView(trip: trip, route: route)
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.12), radius: 16, y: -4)
        .padding(.horizontal, 8).padding(.bottom, 16)
    }
}

// MARK: - Supporting cells

private struct OptimizedStopRow: View {
    let number: Int
    let stop: Stop
    let leg: RouteLeg?
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(.blue).frame(width: 26, height: 26)
                Text("\(number)").font(.caption2.bold()).foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(stop.name).font(.subheadline.bold()).lineLimit(1)
                if let leg {
                    let mins = Int(leg.travelTimeSeconds / 60)
                    Text("→ \(MKDistanceFormatter().string(fromDistance: leg.distanceMeters)) · \(mins) min")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("\(stop.minutesToSpend) min").font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct StatCell: View {
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

private struct ErrorCard: View {
    let message: String; let onRetry: () -> Void
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill").font(.title2).foregroundStyle(.orange)
            Text(message).font(.subheadline).multilineTextAlignment(.center)
            Button("Try Again", action: onRetry).buttonStyle(.borderedProminent)
        }
        .padding(20)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 10, y: -2)
        .padding(.horizontal, 16).padding(.bottom, 32)
    }
}
