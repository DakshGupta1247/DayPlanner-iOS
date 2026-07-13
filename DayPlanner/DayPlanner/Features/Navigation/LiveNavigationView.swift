//
//  LiveNavigationView.swift
//  DayPlanner
//
//  FR9 — Live Trip Navigation.
//  Shows real-time GPS tracking, live polyline, ETA, arrival detection.
//
//  FR2 additions: LocationTrustChip (top overlay)
//  FR3 additions: ETAEngine speed-based ETA + arrival time + ClosingTimeVerdict rows
//

import MapKit
import SwiftUI

struct LiveNavigationView: View {

    @State private var viewModel: LiveNavigationViewModel
    @Environment(\.dismiss) private var dismiss

    init(trip: Trip, route: ComputedRoute) {
        _viewModel = State(initialValue: LiveNavigationViewModel(trip: trip, route: route))
    }

    var body: some View {
        ZStack(alignment: .bottom) {

            // — Full-screen live map —
            liveMap
                .ignoresSafeArea()

            // — GPS trust chip (top-left) —
            VStack {
                HStack {
                    LocationTrustChip(trust: viewModel.locationService.latestTrust)
                        .padding(.leading, 16)
                        .padding(.top, 60)
                    Spacer()
                }
                Spacer()
            }
            .zIndex(5)

            // — Overlaid bottom card —
            if !viewModel.tripComplete {
                bottomOverlay
            }

            // — Arrival banner (slides in from top) —
            if viewModel.showingArrivalBanner {
                ArrivalBanner(stopName: viewModel.currentStop?.name ?? "") {
                    viewModel.markCurrentStopArrived()
                }
                .padding(.horizontal, 16)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 60)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(response: 0.4), value: viewModel.showingArrivalBanner)
            }
        }
        .navigationTitle("Live Navigation")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear  { viewModel.startLiveTracking() }
        .onDisappear { viewModel.stopLiveTracking() }
        .fullScreenCover(isPresented: $viewModel.isDayComplete) {
            if let summary = viewModel.daySummary {
                DayCompleteView(
                    summary: summary,
                    completedStops: viewModel.completedStops
                ) {
                    viewModel.isDayComplete = false
                    dismiss()
                }
            }
        }
    }

    // MARK: - Live Map

    @ViewBuilder
    private var liveMap: some View {
        if viewModel.locationService.isDenied {
            locationDeniedView
        } else {
            Map(position: $viewModel.cameraPosition) {
                // Use a custom annotation driven by the location provider (works with
                // both real GPS and GPXReplayProvider) instead of UserAnnotation which
                // only tracks the simulator's built-in location — not the GPX replay.
                if let loc = viewModel.locationService.currentLocation {
                    Annotation("", coordinate: loc.coordinate) {
                        ZStack {
                            Circle()
                                .fill(.blue.opacity(0.25))
                                .frame(width: 28, height: 28)
                            Circle()
                                .fill(.white)
                                .frame(width: 16, height: 16)
                            Circle()
                                .fill(.blue)
                                .frame(width: 12, height: 12)
                        }
                        .shadow(radius: 3)
                    }
                }

                if let polyline = viewModel.livePolyline {
                    MapPolyline(polyline)
                        .stroke(.blue, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                }

                ForEach(Array(viewModel.stops.enumerated()), id: \.element.id) { index, stop in
                    Annotation("", coordinate: stop.coordinate) {
                        LiveStopPin(
                            number: index + 1,
                            isCompleted: index < viewModel.currentStopIndex,
                            isCurrent: index == viewModel.currentStopIndex
                        )
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic))
        }
    }

    // MARK: - Bottom Overlay

    @ViewBuilder
    private var bottomOverlay: some View {
        VStack(spacing: 12) {
            LiveProgressBar(viewModel: viewModel)

            if let stop = viewModel.currentStop {
                LiveStopCard(
                    stop: stop,
                    stopLabel: viewModel.stopCountLabel,
                    eta: viewModel.formattedETA,
                    arrivalTime: viewModel.formattedArrivalTime,
                    etaLoading: viewModel.etaIsLoading,
                    verdict: viewModel.closingTimeVerdict,
                    onNavigate: { viewModel.navigateInMaps() },
                    onArrived:  { viewModel.markCurrentStopArrived() }
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
    }

    // MARK: - Location Denied View

    private var locationDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("Location Access Required")
                .font(.title3.bold())
            Text("Go to Settings → Privacy → Location Services → DayPlanner and set to \"While Using\".")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Location Trust Chip

private struct LocationTrustChip: View {
    let trust: LocationTrust?

    private var dotColor: Color {
        switch trust {
        case .trusted:    return .green
        case .degraded:   return .yellow
        case .untrusted:  return .red
        case nil:         return .gray
        }
    }

    private var label: String {
        switch trust {
        case .trusted:    return "GPS Good"
        case .degraded:   return "GPS Weak"
        case .untrusted:  return "GPS Lost"
        case nil:         return "GPS…"
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption2.bold())
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.regularMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
}

// MARK: - Live Stop Pin

private struct LiveStopPin: View {
    let number: Int
    let isCompleted: Bool
    let isCurrent: Bool

    private var color: Color {
        if isCompleted { return .green }
        if isCurrent   { return .blue }
        return .gray.opacity(0.6)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 32, height: 32)
                .shadow(radius: 3)
            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
            } else {
                Text("\(number)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
            }
        }
        .scaleEffect(isCurrent ? 1.2 : 1.0)
        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                   value: isCurrent)
    }
}

// MARK: - Live Progress Bar

private struct LiveProgressBar: View {
    let viewModel: LiveNavigationViewModel

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(viewModel.stops.enumerated()), id: \.element.id) { index, _ in
                RoundedRectangle(cornerRadius: 3)
                    .fill(index < viewModel.currentStopIndex ? Color.green :
                          index == viewModel.currentStopIndex ? Color.blue :
                          Color.gray.opacity(0.25))
                    .frame(height: 6)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.currentStopIndex)
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Closing Verdict Row

private struct ClosingVerdictRow: View {
    let verdict: ClosingTimeVerdict

    var body: some View {
        switch verdict {
        case .makeIt:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("You'll make it").font(.caption.bold()).foregroundStyle(.green)
            }
        case .cuttingClose:
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text("Cutting it close").font(.caption.bold()).foregroundStyle(.orange)
            }
        case .wontMakeIt:
            HStack(spacing: 6) {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                Text("Won't make it").font(.caption.bold()).foregroundStyle(.red)
            }
        case .noClosingTime:
            EmptyView()
        }
    }
}

// MARK: - Live Stop Card

private struct LiveStopCard: View {
    let stop: Stop
    let stopLabel: String
    let eta: String
    let arrivalTime: String
    let etaLoading: Bool
    let verdict: ClosingTimeVerdict
    let onNavigate: () -> Void
    let onArrived: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3)
                .fill(.secondary.opacity(0.4))
                .frame(width: 36, height: 4)
                .padding(.top, 10)

            VStack(alignment: .leading, spacing: 12) {
                // Stop header + ETA badge
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Stop \(stopLabel)".uppercased())
                            .font(.caption2.bold())
                            .foregroundStyle(.blue)
                        Text(stop.name)
                            .font(.headline)
                        Text(stop.address)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        if etaLoading {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Text(eta)
                                .font(.title3.bold())
                                .foregroundStyle(.blue)
                            if !arrivalTime.isEmpty {
                                Text("Arrives \(arrivalTime)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("ETA")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(width: 90)
                }

                // Closing time verdict
                ClosingVerdictRow(verdict: verdict)

                Divider()

                // Action buttons
                HStack(spacing: 12) {
                    Button(action: onNavigate) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                            Text("Maps")
                        }
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button(action: onArrived) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Arrived")
                        }
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.green.opacity(0.15))
                        .foregroundStyle(.green)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.12), radius: 16, y: -4)
    }
}

// MARK: - Arrival Banner

private struct ArrivalBanner: View {
    let stopName: String
    let onArrived: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "location.fill")
                .font(.title3)
                .foregroundStyle(.white)
                .padding(10)
                .background(.green)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("You've arrived!")
                    .font(.subheadline.bold())
                Text(stopName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button("Mark Arrived", action: onArrived)
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.green)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(14)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .green.opacity(0.2), radius: 12, y: 4)
    }
}


#Preview {
    NavigationStack {
        LiveNavigationView(
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
                    RouteLeg(from: Stop(name: "Ferry Building", address: "", latitude: 37.7955,
                                        longitude: -122.3937, minutesToSpend: 45),
                             to:   Stop(name: "Golden Gate Park", address: "", latitude: 37.7694,
                                        longitude: -122.4862, minutesToSpend: 90),
                             distanceMeters: 8200, travelTimeSeconds: 780,
                             polyline: MKPolyline())
                ],
                totalDistanceMeters: 8200,
                totalTravelTimeSeconds: 780
            )
        )
    }
}
