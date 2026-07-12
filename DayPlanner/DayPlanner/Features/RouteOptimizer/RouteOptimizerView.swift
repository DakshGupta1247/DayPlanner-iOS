//
//  RouteOptimizerView.swift
//  DayPlanner (PlanDay)
//
//  Shows the optimized route for a single DayPlan on a full-screen map.
//
//  Two modes:
//  - Normal: map + bottom card with route stats, Itinerary, Start Day buttons
//  - Edit:   drag-to-reorder stop list (List + .onMove), Recalculate button,
//            Cancel with discard confirmation if changes were made
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
            if viewModel.isEditingRoute {
                editRouteSheet
            } else {
                bottomCard
            }

            // Success toast
            if viewModel.showSuccessToast {
                toastBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .navigationTitle(viewModel.isEditingRoute ? "Edit Route" : "Optimized Route")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.isEditingRoute {
                    Button("Cancel") { viewModel.requestCancelEdit() }
                        .foregroundStyle(.red)
                } else {
                    Button { Task { await viewModel.calculateRoute() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
        }
        .task { await viewModel.calculateRoute() }
        .animation(.easeInOut(duration: 0.35), value: viewModel.isEditingRoute)
        .animation(.spring(response: 0.4), value: viewModel.showSuccessToast)
        // Discard confirmation
        .alert("Discard Changes?", isPresented: $viewModel.showDiscardAlert) {
            Button("Keep Editing", role: .cancel) { viewModel.showDiscardAlert = false }
            Button("Discard", role: .destructive) { viewModel.discardEdits() }
        } message: {
            Text("Your reordered stops will not be saved.")
        }
    }

    // MARK: - Map

    @ViewBuilder
    private var mapLayer: some View {
        Map(position: $viewModel.cameraPosition) {
            let stops: [Stop] = {
                if viewModel.isEditingRoute {
                    return viewModel.reorderedStops
                } else if case .success(let route) = viewModel.routeState {
                    return route.orderedStops
                }
                return viewModel.dayPlan.stops
            }()

            // Polylines only in normal success state
            if !viewModel.isEditingRoute, case .success(let route) = viewModel.routeState {
                ForEach(Array(route.legs.enumerated()), id: \.offset) { _, leg in
                    MapPolyline(leg.polyline).stroke(.blue, lineWidth: 4)
                }
            }

            ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                Annotation("", coordinate: stop.coordinate) {
                    RouteStopPin(number: index + 1,
                                 isFirst: index == 0,
                                 isLast: index == stops.count - 1)
                }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Bottom card (normal mode)

    @ViewBuilder
    private var bottomCard: some View {
        switch viewModel.routeState {
        case .idle:       EmptyView()
        case .loading:    LoadingCard()
        case .success(let route):
            RouteSuccessCard(route: route, trip: viewModel.trip) {
                viewModel.enterEditMode()
            }
        case .failure(let msg):
            ErrorCard(message: msg) { Task { await viewModel.calculateRoute() } }
        }
    }

    // MARK: - Edit route sheet

    private var editRouteSheet: some View {
        VStack(spacing: 0) {
            // Pill handle
            RoundedRectangle(cornerRadius: 3)
                .fill(.secondary.opacity(0.4))
                .frame(width: 44, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 6)

            HStack {
                Text("Drag to reorder stops")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Text("\(viewModel.reorderedStops.count) stops")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            Divider()

            // Draggable stop list
            List {
                ForEach(Array(viewModel.reorderedStops.enumerated()), id: \.element.id) { index, stop in
                    DraggableStopRow(
                        number: index + 1,
                        stop: stop,
                        isFirst: index == 0,
                        isLast: index == viewModel.reorderedStops.count - 1
                    )
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(Color(.systemBackground))
                }
                .onMove { source, destination in
                    viewModel.moveStop(from: source, to: destination)
                }
            }
            .listStyle(.plain)
            .environment(\.editMode, .constant(.active))
            .frame(maxHeight: 320)

            Divider()

            // Recalculate button
            Button {
                Task { await viewModel.recalculateWithUserOrder() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.subheadline.bold())
                    Text("Recalculate Route")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(viewModel.hasUserReordered
                             ? Color(red: 0.145, green: 0.392, blue: 0.922) // #2563EB
                             : Color.gray.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .animation(.easeInOut(duration: 0.2), value: viewModel.hasUserReordered)
            }
            .disabled(!viewModel.hasUserReordered || viewModel.isLoading)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.12), radius: 16, y: -4)
        .padding(.horizontal, 8)
        .padding(.bottom, 16)
    }

    // MARK: - Toast

    private var toastBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Route updated based on your preferences")
                .font(.subheadline.bold())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        .frame(maxWidth: .infinity, alignment: .top)
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }
}

// MARK: - Draggable Stop Row

private struct DraggableStopRow: View {
    let number: Int
    let stop: Stop
    let isFirst: Bool
    let isLast: Bool

    private var isLocked: Bool { isFirst || isLast }
    private var pinColor: Color { isFirst ? .green : isLast ? .red : .blue }

    var body: some View {
        HStack(spacing: 12) {
            // Drag handle — hidden for first/last (locked)
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(isLocked ? Color.clear : Color.secondary.opacity(0.6))
                .frame(width: 24)

            // Number badge
            ZStack {
                Circle()
                    .fill(isLocked ? Color.gray.opacity(0.25) : pinColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(number)")
                        .font(.caption.bold())
                        .foregroundStyle(pinColor)
                }
            }

            // Stop info
            VStack(alignment: .leading, spacing: 2) {
                Text(stop.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(isLocked ? .secondary : .primary)
                    .lineLimit(1)
                Text(stop.address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Duration
            Text("\(stop.minutesToSpend) min")
                .font(.caption)
                .foregroundStyle(.secondary)
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
    let onEditTapped: () -> Void

    @State private var showingItinerary  = false
    @State private var showingNavigation = false
    @State private var showPullHint = true

    var body: some View {
        VStack(spacing: 0) {

            // Drag handle + pull hint
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(.secondary.opacity(0.5))
                    .frame(width: 44, height: 5)

                if showPullHint {
                    Label("Swipe up for details", systemImage: "chevron.up")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                withAnimation(.easeOut(duration: 0.4)) { showPullHint = false }
                            }
                        }
                }
            }
            .padding(.top, 10)
            .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 16) {

                // Stats
                HStack(spacing: 0) {
                    StatCell(value: route.formattedDistance,      label: "Distance",    symbol: "road.lanes",         color: .blue)
                    Divider().frame(height: 40)
                    StatCell(value: route.formattedTravelTime,    label: "Travel time", symbol: "car.fill",           color: .orange)
                    Divider().frame(height: 40)
                    StatCell(value: "\(route.orderedStops.count)", label: "Stops",      symbol: "mappin.circle.fill", color: .green)
                }

                Divider()

                // Header row with Edit button
                HStack {
                    Text("Optimized order")
                        .font(.caption.bold()).foregroundStyle(.secondary).textCase(.uppercase)
                    Spacer()
                    Button(action: onEditTapped) {
                        Label("Edit", systemImage: "pencil")
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.blue.opacity(0.1))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                }

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
