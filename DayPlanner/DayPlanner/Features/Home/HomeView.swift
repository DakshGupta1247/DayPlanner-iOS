//
//  HomeView.swift
//  DayPlanner (PlanDay)
//
//  Redesigned home screen with:
//  - Greeting header
//  - "Today's Focus" highlighted card (if a plan is active today)
//  - "All Plans" scrollable list of Day Cards and Trip Cards
//  - FAB (Floating Action Button) with animated two-option menu
//  - Swipe actions: Edit (blue) and Delete (red) with confirmation alert
//

import SwiftUI

struct HomeView: View {

    @State private var viewModel = HomeViewModel()
    @State private var showingSettings = false
    @State private var showingProfiles = false
    @State private var showingHistory  = false
    @State private var profileService = ProfileService.shared

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {

                        // — Greeting —
                        GreetingHeader(
                            greeting: viewModel.greeting,
                            date: viewModel.formattedDate
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 24)

                        // — Today's Focus —
                        if let today = viewModel.todaysItem {
                            SectionHeader(title: "Today's Focus", symbol: "location.fill", color: .blue)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 10)

                            PlanCard(item: today, viewModel: viewModel, isHighlighted: true)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 28)
                        }

                        // — All Plans —
                        SectionHeader(title: "All Plans", symbol: "calendar", color: .secondary)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 10)

                        if viewModel.sortedItems.isEmpty {
                            EmptyPlansState()
                                .padding(.horizontal, 20)
                                .padding(.top, 40)
                        } else {
                            VStack(spacing: 14) {
                                ForEach(viewModel.sortedItems) { item in
                                    PlanCard(item: item, viewModel: viewModel, isHighlighted: false)
                                        .padding(.horizontal, 16)
                                }
                            }
                            .padding(.bottom, 100) // space for FAB
                        }
                    }
                }
                .navigationTitle("PlanDay")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showingProfiles = true } label: {
                            ProfileAvatarButton(profile: profileService.activeProfile)
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: 4) {
                            Button { showingHistory = true } label: {
                                Image(systemName: "clock.arrow.circlepath")
                            }
                            Button { showingSettings = true } label: {
                                Image(systemName: "gearshape")
                            }
                        }
                    }
                }
                .onAppear { viewModel.reload() }
                .onChange(of: profileService.activeProfile?.id) { viewModel.reload() }

                // — FAB overlay —
                FABMenu(viewModel: viewModel)
                    .padding(.trailing, 20)
                    .padding(.bottom, 32)
            }
        }
        .sheet(isPresented: $showingProfiles) {
            ProfileSwitcherView()
                .onDisappear { viewModel.reload() }
        }
        .sheet(isPresented: $showingSettings) { SettingsView() }
        .sheet(isPresented: $showingHistory)  { TripHistoryView() }
        // Create sheets
        .sheet(isPresented: $viewModel.showingDayPlanBuilder) {
            DayPlanBuilderView { plan in viewModel.saveDayPlan(plan) }
        }
        .sheet(isPresented: $viewModel.showingTripBuilder) {
            TripBuilderView { trip in viewModel.saveTrip(trip) }
        }
        // Edit sheets — driven by which item is set
        .sheet(item: $viewModel.editingDayPlan) { plan in
            DayPlanBuilderView(editing: plan) { updated in
                viewModel.saveDayPlan(updated)
            }
        }
        .sheet(item: $viewModel.editingTrip) { trip in
            TripBuilderView(editing: trip) { updated in
                viewModel.saveTrip(updated)
            }
        }
        // Delete confirmation alert
        .alert("Delete Plan?", isPresented: Binding(
            get: { viewModel.itemPendingDelete != nil },
            set: { if !$0 { viewModel.itemPendingDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let item = viewModel.itemPendingDelete {
                    viewModel.delete(item)
                }
                viewModel.itemPendingDelete = nil
            }
            Button("Cancel", role: .cancel) {
                viewModel.itemPendingDelete = nil
            }
        } message: {
            if let item = viewModel.itemPendingDelete {
                switch item {
                case .singleDay(let plan):
                    Text("\"\(plan.name)\" will be permanently removed.")
                case .multiDayTrip(let trip):
                    Text("\"\(trip.name)\" and all \(trip.days.count) day\(trip.days.count == 1 ? "" : "s") will be permanently removed.")
                }
            }
        }
    }
}

// MARK: - Greeting Header

private struct GreetingHeader: View {
    let greeting: String
    let date: String
    @State private var profileService = ProfileService.shared

    private var displayName: String {
        profileService.activeProfile?.name ?? "there"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(greeting), \(displayName)!")
                .font(.title2.bold())
            Text(date)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Section Header

private struct SectionHeader: View {
    let title: String
    let symbol: String
    let color: Color

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.caption.bold())
            .foregroundStyle(color)
            .textCase(.uppercase)
    }
}

// MARK: - Plan Card (dispatcher)

/// Renders the right card type depending on whether the item is a Day Plan or Trip.
private struct PlanCard: View {
    let item: PlanItem
    let viewModel: HomeViewModel
    let isHighlighted: Bool

    var body: some View {
        switch item {
        case .singleDay(let plan):
            DayPlanCard(plan: plan, isHighlighted: isHighlighted)
                .contextMenu {
                    Button { viewModel.startEditing(item) } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) { viewModel.itemPendingDelete = item } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        viewModel.itemPendingDelete = item
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button {
                        viewModel.startEditing(item)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
        case .multiDayTrip(let trip):
            TripCard(trip: trip, isHighlighted: isHighlighted)
                .contextMenu {
                    Button { viewModel.startEditing(item) } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) { viewModel.itemPendingDelete = item } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        viewModel.itemPendingDelete = item
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button {
                        viewModel.startEditing(item)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
        }
    }
}

// MARK: - Day Plan Card

private struct DayPlanCard: View {
    let plan: DayPlan
    let isHighlighted: Bool

    @State private var showingRoute = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Header row
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(plan.name)
                        .font(.headline)
                    Text(plan.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatusBadge(status: plan.status)
            }

            Divider()

            // Stats row
            HStack(spacing: 0) {
                MiniStat(value: "\(plan.stops.count)",
                         label: plan.stops.count == 1 ? "Stop" : "Stops",
                         symbol: "mappin.circle.fill", color: .blue)
                Divider().frame(height: 32)
                MiniStat(value: formattedDuration(plan.totalMinutesToSpend),
                         label: "Planned", symbol: "clock.fill", color: .orange)
                Divider().frame(height: 32)
                MiniStat(value: plan.travelMode.rawValue,
                         label: "Mode",
                         symbol: plan.travelMode.symbolName, color: .purple)
            }

            // Action buttons (only show if not empty)
            if !plan.stops.isEmpty {
                HStack(spacing: 10) {
                    Button { showingRoute = true } label: {
                        Label("View Route", systemImage: "map.fill")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
        .padding(16)
        .background(isHighlighted ? AnyShapeStyle(.blue.opacity(0.07)) : AnyShapeStyle(.regularMaterial))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(isHighlighted ? 0.10 : 0.06), radius: 10, y: 3)
        .overlay(
            isHighlighted
                ? RoundedRectangle(cornerRadius: 18).stroke(.blue.opacity(0.3), lineWidth: 1.5)
                : nil
        )
        .navigationDestination(isPresented: $showingRoute) {
            RouteOptimizerView(dayPlan: plan)
        }
    }

    private func formattedDuration(_ m: Int) -> String {
        guard m > 0 else { return "—" }
        let h = m / 60; let mins = m % 60
        if h > 0 && mins > 0 { return "\(h)h \(mins)m" }
        return h > 0 ? "\(h)h" : "\(mins)m"
    }
}

// MARK: - Trip Card

private struct TripCard: View {
    let trip: Trip
    let isHighlighted: Bool

    @State private var showingDetail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Header
            HStack(alignment: .top) {
                // Emoji + color blob
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.hex( trip.coverColor).opacity(0.2))
                        .frame(width: 44, height: 44)
                    Text(trip.emoji).font(.title2)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(trip.name).font(.headline)
                    Text(trip.dateRangeLabel)
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                StatusBadge(status: trip.status)
            }

            Divider()

            // Summary
            HStack(spacing: 0) {
                MiniStat(value: "\(trip.days.count)",
                         label: trip.days.count == 1 ? "Day" : "Days",
                         symbol: "calendar", color: .indigo)
                Divider().frame(height: 32)
                MiniStat(value: "\(trip.totalStops)",
                         label: trip.totalStops == 1 ? "Stop" : "Stops",
                         symbol: "mappin.circle.fill", color: .blue)
                Divider().frame(height: 32)
                MiniStat(value: trip.travelMode.rawValue,
                         label: "Mode",
                         symbol: trip.travelMode.symbolName, color: .purple)
            }

            // View Trip button
            Button { showingDetail = true } label: {
                Label("View Trip", systemImage: "chevron.right")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.hex( trip.coverColor).opacity(0.15))
                    .foregroundStyle(Color.hex( trip.coverColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(16)
        .background(isHighlighted ? AnyShapeStyle(Color.hex( trip.coverColor).opacity(0.07)) : AnyShapeStyle(.regularMaterial))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(isHighlighted ? 0.10 : 0.06), radius: 10, y: 3)
        .overlay(
            isHighlighted
                ? RoundedRectangle(cornerRadius: 18).stroke(Color.hex( trip.coverColor).opacity(0.3), lineWidth: 1.5)
                : nil
        )
        .navigationDestination(isPresented: $showingDetail) {
            TripDetailView(trip: trip)
        }
    }
}

// MARK: - Status Badge

private struct StatusBadge: View {
    let status: PlanStatus

    private var color: Color {
        switch status {
        case .active:    return .blue
        case .upcoming:  return .orange
        case .completed: return .green
        }
    }

    var body: some View {
        Label(status.label, systemImage: status.symbolName)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

// MARK: - Mini Stat

private struct MiniStat: View {
    let value: String
    let label: String
    let symbol: String
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: symbol).font(.caption).foregroundStyle(color)
            Text(value).font(.subheadline.bold())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Empty State

private struct EmptyPlansState: View {
    var body: some View {
        VStack(spacing: 20) {
            Circle()
                .fill(.blue.opacity(0.07))
                .frame(width: 120, height: 120)
                .overlay(
                    Image(systemName: "map")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(.blue.opacity(0.6))
                )
            VStack(spacing: 6) {
                Text("No plans yet")
                    .font(.title3.bold())
                Text("Tap + to start planning\nyour day or trip.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - FAB Menu

private struct FABMenu: View {
    @Bindable var viewModel: HomeViewModel

    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {

            // Option buttons — slide up when menu is open
            if viewModel.isFABMenuOpen {
                FABOption(label: "Plan a Trip", symbol: "map.fill", color: .indigo) {
                    viewModel.isFABMenuOpen = false
                    viewModel.showingTripBuilder = true
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))

                FABOption(label: "Plan a Day", symbol: "calendar.badge.plus", color: .blue) {
                    viewModel.isFABMenuOpen = false
                    viewModel.showingDayPlanBuilder = true
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Main + button
            Button {
                viewModel.toggleFAB()
            } label: {
                Image(systemName: viewModel.isFABMenuOpen ? "xmark" : "plus")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(.blue)
                    .clipShape(Circle())
                    .shadow(color: .blue.opacity(0.35), radius: 10, y: 4)
                    .rotationEffect(.degrees(viewModel.isFABMenuOpen ? 45 : 0))
                    .animation(.spring(response: 0.3), value: viewModel.isFABMenuOpen)
            }
        }
    }
}

private struct FABOption: View {
    let label: String
    let symbol: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(label)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                Image(systemName: symbol)
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(color)
                    .clipShape(Circle())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.regularMaterial)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
        }
    }
}


// MARK: - Profile Avatar Button

private struct ProfileAvatarButton: View {
    let profile: UserProfile?

    private var color: Color {
        Color.hex( profile?.accentColor.hexValue ?? "#3B82F6")
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: 32, height: 32)
            Text(profile?.initials ?? "?")
                .font(.caption.bold())
                .foregroundStyle(color)
        }
    }
}

#Preview { HomeView() }
