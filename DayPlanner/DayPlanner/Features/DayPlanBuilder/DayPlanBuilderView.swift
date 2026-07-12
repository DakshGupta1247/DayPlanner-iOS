//
//  DayPlanBuilderView.swift
//  DayPlanner (PlanDay)
//
//  Single-day plan builder sheet.
//  User picks a date, searches for stops, then confirms.
//  Supports create mode (default init) and edit mode (init(editing:)).
//

import MapKit
import SwiftUI

struct DayPlanBuilderView: View {

    @State private var viewModel: DayPlanBuilderViewModel
    @State private var searchService = PlaceSearchService()
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    @Environment(\.dismiss) private var dismiss

    // MARK: - Create mode
    init(onConfirmed: @escaping (DayPlan) -> Void) {
        let vm = DayPlanBuilderViewModel()
        vm.onConfirmed = onConfirmed
        _viewModel = State(initialValue: vm)
    }

    // MARK: - Edit mode
    init(editing plan: DayPlan, onConfirmed: @escaping (DayPlan) -> Void) {
        let vm = DayPlanBuilderViewModel(editing: plan)
        vm.onConfirmed = onConfirmed
        _viewModel = State(initialValue: vm)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search for a place...", text: $searchText)
                        .focused($isSearchFocused)
                        .submitLabel(.search)
                        .autocorrectionDisabled()
                    if !searchText.isEmpty {
                        Button { searchText = ""; searchService.clear(); isSearchFocused = false } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider()

                // Content
                if isSearchFocused || !searchText.isEmpty {
                    searchResultsList
                } else {
                    mainContent
                }

                Divider()

                // Bottom bar
                VStack(spacing: 10) {
                    let total = viewModel.stops.count
                    if total > 0 {
                        Text("\(total) stop\(total == 1 ? "" : "s") added")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Button {
                        viewModel.confirm()
                        dismiss()
                    } label: {
                        Text(viewModel.canConfirm
                             ? (viewModel.isEditing ? "Save Changes" : "Create Day Plan")
                             : "Add at least one stop")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(viewModel.canConfirm ? Color.blue : Color.gray.opacity(0.3))
                            .foregroundStyle(viewModel.canConfirm ? .white : .secondary)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(!viewModel.canConfirm)
                }
                .padding(16)
            }
            .navigationTitle(viewModel.isEditing ? "Edit Day Plan" : "Plan a Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { EditButton() }
            }
        }
        .onChange(of: searchText) { _, v in searchService.search(query: v) }
    }

    // MARK: - Search results

    @ViewBuilder
    private var searchResultsList: some View {
        if searchService.isLoading {
            VStack { Spacer(); ProgressView("Searching..."); Spacer() }
        } else if searchService.results.isEmpty && !searchText.isEmpty {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "magnifyingglass").font(.system(size: 40)).foregroundStyle(.secondary)
                Text("No results for \"\(searchText)\"").foregroundStyle(.secondary)
                Spacer()
            }
        } else {
            List(searchService.results, id: \.self) { item in
                let coord = item.location.coordinate
                let added = viewModel.stops.contains { abs($0.latitude - coord.latitude) < 0.0001 }
                PlaceSearchResultRow(mapItem: item, onAdd: {
                    viewModel.addStop(from: item)
                    searchText = ""; searchService.clear(); isSearchFocused = false
                }, isAdded: added)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
            .listStyle(.plain)
        }
    }

    // MARK: - Main content (settings + stops)

    @ViewBuilder
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 0) {

                // Settings: name, date, travel mode
                Group {
                    HStack {
                        Text("Name").font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                        TextField("Day Plan", text: $viewModel.name)
                            .font(.subheadline.bold()).multilineTextAlignment(.trailing)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    Divider().padding(.leading, 16)

                    DatePicker("Date", selection: $viewModel.date, displayedComponents: .date)
                        .font(.subheadline).padding(.horizontal, 16).padding(.vertical, 6)
                    Divider().padding(.leading, 16)

                    Picker("Travel Mode", selection: $viewModel.travelMode) {
                        ForEach(TravelMode.allCases, id: \.self) { m in
                            Label(m.rawValue, systemImage: m.symbolName).tag(m)
                        }
                    }
                    .font(.subheadline).padding(.horizontal, 16).padding(.vertical, 6)
                    Divider()
                }
                .background(Color(.systemBackground))

                // Stop list or empty hint
                if viewModel.stops.isEmpty {
                    VStack(spacing: 14) {
                        Spacer(minLength: 40)
                        Image(systemName: "magnifyingglass.circle")
                            .font(.system(size: 52)).foregroundStyle(.blue.opacity(0.4))
                        Text("Search above to add stops")
                            .font(.headline)
                        Spacer(minLength: 40)
                    }
                } else {
                    // Mini map
                    Map(position: $viewModel.cameraPosition) {
                        ForEach(Array(viewModel.stops.enumerated()), id: \.element.id) { i, s in
                            Annotation("", coordinate: s.coordinate) {
                                NumberedPin(number: i + 1)
                            }
                        }
                    }
                    .frame(height: 180)

                    Divider()

                    LazyVStack(spacing: 0) {
                        ForEach(Array(viewModel.stops.enumerated()), id: \.element.id) { i, stop in
                            StopRow(
                                number: i + 1,
                                stop: stop,
                                onRemove: { viewModel.removeStop(stop) },
                                onDurationChanged: { viewModel.updateDuration(for: stop, minutes: $0) }
                            )
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            Divider().padding(.leading, 60)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Shared sub-views

struct NumberedPin: View {
    let number: Int
    var body: some View {
        ZStack {
            Circle().fill(.blue).frame(width: 28, height: 28).shadow(radius: 2)
            Text("\(number)").font(.caption.bold()).foregroundStyle(.white)
        }
    }
}

struct StopRow: View {
    let number: Int
    let stop: Stop
    let onRemove: () -> Void
    // Called when user changes the time-at-stop. Optional so existing callers without
    // duration editing still compile (TripBuilderView reuses this struct too).
    var onDurationChanged: ((Int) -> Void)? = nil

    @State private var showingDurationPicker = false

    var body: some View {
        HStack(spacing: 12) {
            NumberedPin(number: number)
            VStack(alignment: .leading, spacing: 2) {
                Text(stop.name).font(.subheadline.bold()).lineLimit(1)
                Text(stop.address).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()

            // Duration badge — tappable if a callback was provided
            if onDurationChanged != nil {
                Button { showingDurationPicker = true } label: {
                    Text("\(stop.minutesToSpend) min")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill").foregroundStyle(.red.opacity(0.8))
            }
        }
        .padding(.vertical, 2)
        .sheet(isPresented: $showingDurationPicker) {
            StopDurationPickerSheet(
                stopName: stop.name,
                currentMinutes: stop.minutesToSpend
            ) { newMinutes in
                onDurationChanged?(newMinutes)
            }
        }
    }
}

// MARK: - Stop Duration Picker Sheet
// A compact half-height sheet with a slider + quick-pick presets.
// Used both in DayPlanBuilderView (planning) and ItineraryView (adjusting).
struct StopDurationPickerSheet: View {
    let stopName: String
    let currentMinutes: Int
    let onConfirm: (Int) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var minutes: Double

    init(stopName: String, currentMinutes: Int, onConfirm: @escaping (Int) -> Void) {
        self.stopName = stopName
        self.currentMinutes = currentMinutes
        self.onConfirm = onConfirm
        _minutes = State(initialValue: Double(currentMinutes))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {

                Text(stopName)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Big time display
                Text("\(Int(minutes)) min")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.blue)

                // Slider: 5 → 240 min, step 5
                Slider(value: $minutes, in: 5...240, step: 5)
                    .padding(.horizontal)

                HStack {
                    Text("5 min").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("4 hours").font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                // Quick-pick presets
                HStack(spacing: 10) {
                    ForEach([15, 30, 45, 60, 90], id: \.self) { preset in
                        Button("\(preset)m") { minutes = Double(preset) }
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Int(minutes) == preset ? Color.blue : Color.blue.opacity(0.1))
                            .foregroundStyle(Int(minutes) == preset ? .white : .blue)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }

                Spacer()

                Button {
                    onConfirm(Int(minutes))
                    dismiss()
                } label: {
                    Text("Confirm")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal)
            }
            .padding(.top, 24)
            .navigationTitle("Time at Stop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    DayPlanBuilderView { plan in print("Created: \(plan.name)") }
}
