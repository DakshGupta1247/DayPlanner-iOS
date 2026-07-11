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
                // Settings button in top-right (will link to FR8 later)
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        // TODO: open settings (FR8)
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
        // Present the TripBuilder sheet (FR3) when the ViewModel says so
        .sheet(isPresented: $viewModel.isShowingTripBuilder) {
            // Placeholder until FR3 is built
            TripBuilderPlaceholder(viewModel: viewModel)
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

    var body: some View {
        VStack(spacing: 16) {

            // Reusable summary card from Components/
            TripSummaryCard(trip: trip)

            // Action buttons row
            HStack(spacing: 12) {
                // View full itinerary (FR5)
                Button {
                    // TODO: navigate to itinerary (FR5)
                } label: {
                    Label("View Itinerary", systemImage: "list.bullet.rectangle")
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
    }
}

// MARK: - Trip Builder Placeholder

/// Temporary sheet shown until FR3 (TripBuilder) is built.
/// Lets us test that the sheet presentation works correctly right now.
private struct TripBuilderPlaceholder: View {
    let viewModel: HomeViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.orange)
                Text("Trip Builder")
                    .font(.title.bold())
                Text("Coming in FR3!")
                    .foregroundStyle(.secondary)

                // For testing: add a sample trip so we can see the summary card
                Button("Add Sample Trip (for testing)") {
                    let sampleTrip = Trip(
                        name: "My Day Out",
                        date: .now,
                        stops: [
                            Stop(name: "Coffee Shop", address: "123 Main St", latitude: 37.77, longitude: -122.41, minutesToSpend: 30),
                            Stop(name: "Golden Gate Park", address: "San Francisco, CA", latitude: 37.76, longitude: -122.45, minutesToSpend: 90),
                            Stop(name: "Fisherman's Wharf", address: "Beach St, SF", latitude: 37.80, longitude: -122.41, minutesToSpend: 60)
                        ],
                        travelMode: .walking
                    )
                    viewModel.setTrip(sampleTrip)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .navigationTitle("Plan Your Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    HomeView()
}
