//
//  HomeView.swift
//  DayPlanner
//
//  The main screen users see every day after onboarding.
//  Shows a greeting, today's date, and either:
//    - An empty state (no trip) with a "Plan Your Day" CTA
//    - A trip summary card (trip exists) with a "View Trip" button
//

import SwiftUI

struct HomeView: View {

    // @State creates the ViewModel and owns it for the lifetime of this view.
    // We use @State (not a constant) because @Observable ViewModels need
    // to be stored as state to properly track changes in iOS 17+.
    @State private var viewModel = HomeViewModel()
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // — Greeting header —
                    GreetingHeaderView(
                        greeting: viewModel.greeting,
                        date: viewModel.formattedDate
                    )

                    // — Main content: empty state OR trip card —
                    if viewModel.hasTripToday, let trip = viewModel.currentTrip {
                        // Trip exists: show the summary card + action buttons
                        TripExistsSection(trip: trip, viewModel: viewModel)
                    } else {
                        // No trip: show the empty state prompt
                        EmptyStateSection(viewModel: viewModel)
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .navigationTitle("DayPlanner")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
        // Settings sheet (FR8)
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        // Present the real TripBuilder sheet (FR3)
        .sheet(isPresented: $viewModel.isShowingTripBuilder) {
            TripBuilderView { confirmedTrip in
                viewModel.setTrip(confirmedTrip)
            }
        }
    }
}

// MARK: - Greeting Header

/// The "Good morning, Daksh!" + date block at the top of the screen.
private struct GreetingHeaderView: View {
    let greeting: String
    let date: String

    // Read the stored name from UserDefaults (we'll let the user set this in FR8 Settings)
    // Default is "there" so the greeting still makes sense before a name is set.
    @AppStorage("userName") private var userName = "there"

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(greeting), \(userName)!")
                .font(.title2.bold())
            Text(date)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Empty State

/// Shown when no trip is planned for today.
private struct EmptyStateSection: View {
    let viewModel: HomeViewModel

    var body: some View {
        VStack(spacing: 32) {
            // Illustration using SF Symbols
            ZStack {
                Circle()
                    .fill(.blue.opacity(0.08))
                    .frame(width: 180, height: 180)

                VStack(spacing: 8) {
                    Image(systemName: "map")
                        .font(.system(size: 64, weight: .light))
                        .foregroundStyle(.blue.opacity(0.7))
                }
            }
            .padding(.top, 40)

            VStack(spacing: 8) {
                Text("No trip planned yet")
                    .font(.title3.bold())

                Text("Add the places you want to visit\nand we'll build your perfect route.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Primary CTA button
            Button {
                viewModel.startPlanningTrip()
            } label: {
                Label("Plan Your Day", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Trip Exists Section

/// Shown when a trip is already planned.
private struct TripExistsSection: View {
    let trip: Trip
    let viewModel: HomeViewModel

    // Controls navigation to RouteOptimizerView
    @State private var showingRoute = false

    var body: some View {
        VStack(spacing: 16) {

            // Reusable summary card from Components/
            TripSummaryCard(trip: trip)

            // Action buttons row
            HStack(spacing: 12) {
                // View optimized route (FR4) — taps into RouteOptimizerView
                Button {
                    showingRoute = true
                } label: {
                    Label("View Route", systemImage: "map.fill")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                // Edit / rebuild trip (FR3)
                Button {
                    viewModel.startPlanningTrip()
                } label: {
                    Label("Edit Trip", systemImage: "pencil")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }

            // Destructive clear button
            Button(role: .destructive) {
                viewModel.clearTrip()
            } label: {
                Text("Clear Trip")
                    .font(.subheadline)
                    .foregroundStyle(.red.opacity(0.8))
            }
            .padding(.top, 4)
        }
        // NavigationLink destination — pushes RouteOptimizerView onto the stack
        .navigationDestination(isPresented: $showingRoute) {
            RouteOptimizerView(trip: trip)
        }
    }
}


#Preview {
    HomeView()
}
