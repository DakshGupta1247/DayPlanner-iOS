//
//  TripBuilderView.swift
//  DayPlanner (PlanDay)
//
//  Multi-day trip builder sheet.
//  Step 1: Trip name, emoji, cover color.
//  Step 2: Start date, number of days.
//  Step 3: Add stops per day using the day tab bar.
//

import MapKit
import SwiftUI

struct TripBuilderView: View {

    @State private var viewModel: TripBuilderViewModel
    @State private var searchService = PlaceSearchService()
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    @Environment(\.dismiss) private var dismiss

    // Builder step: 0 = metadata, 1 = stops
    @State private var currentStep = 0

    init(onConfirmed: @escaping (Trip) -> Void) {
        let vm = TripBuilderViewModel()
        vm.onConfirmed = onConfirmed
        _viewModel = State(initialValue: vm)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // Step indicator
                StepIndicator(currentStep: currentStep)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)

                Divider()

                if currentStep == 0 {
                    // Step 1: name + emoji + color + dates
                    ScrollView {
                        TripMetadataForm(viewModel: viewModel)
                    }
                } else {
                    // Step 2: stops per day
                    VStack(spacing: 0) {
                        // Search bar
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                            TextField("Search for a place...", text: $searchText)
                                .focused($isSearchFocused)
                                .submitLabel(.search)
                                .autocorrectionDisabled()
                            if !searchText.isEmpty {
                                Button {
                                    searchText = ""; searchService.clear(); isSearchFocused = false
                                } label: {
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

                        if isSearchFocused || !searchText.isEmpty {
                            searchResultsList
                        } else {
                            stopsContent
                        }
                    }
                }

                Divider()

                // Bottom action bar
                bottomBar
                    .padding(16)
            }
            .navigationTitle(currentStep == 0 ? "New Trip" : "Add Stops")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                if currentStep == 1 {
                    ToolbarItem(placement: .topBarTrailing) { EditButton() }
                }
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

    // MARK: - Stops content (day tab bar + map + list)

    @ViewBuilder
    private var stopsContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Day tab bar
                if viewModel.numberOfDays > 1 {
                    Picker("Day", selection: $viewModel.selectedDayIndex) {
                        ForEach(0..<viewModel.numberOfDays, id: \.self) { i in
                            Text("Day \(i + 1)").tag(i)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    Divider()
                }

                if viewModel.stops.isEmpty {
                    VStack(spacing: 14) {
                        Spacer(minLength: 32)
                        Image(systemName: "magnifyingglass.circle")
                            .font(.system(size: 48)).foregroundStyle(.blue.opacity(0.4))
                        Text(viewModel.numberOfDays > 1
                             ? "No stops for Day \(viewModel.selectedDayIndex + 1) yet"
                             : "Search above to add stops")
                            .font(.headline)
                        Spacer(minLength: 32)
                    }
                } else {
                    Map(position: $viewModel.cameraPosition) {
                        ForEach(Array(viewModel.stops.enumerated()), id: \.element.id) { i, s in
                            Annotation("", coordinate: s.coordinate) { NumberedPin(number: i + 1) }
                        }
                    }
                    .frame(height: 160)
                    Divider()
                    LazyVStack(spacing: 0) {
                        ForEach(Array(viewModel.stops.enumerated()), id: \.element.id) { i, stop in
                            StopRow(number: i + 1, stop: stop) { viewModel.removeStop(stop) }
                                .padding(.horizontal, 16).padding(.vertical, 8)
                            Divider().padding(.leading, 60)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Bottom bar

    @ViewBuilder
    private var bottomBar: some View {
        if currentStep == 0 {
            Button {
                withAnimation { currentStep = 1 }
            } label: {
                Text("Next: Add Stops")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        } else {
            VStack(spacing: 10) {
                let total = viewModel.dayStops.reduce(0) { $0 + $1.count }
                if total > 0 {
                    Text("\(total) stop\(total == 1 ? "" : "s") across \(viewModel.numberOfDays) day\(viewModel.numberOfDays == 1 ? "" : "s")")
                        .font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: 10) {
                    Button { withAnimation { currentStep = 0 } } label: {
                        Text("Back")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    Button {
                        viewModel.confirm()
                        dismiss()
                    } label: {
                        Text(viewModel.canConfirm ? "Create Trip" : "Add stops to each day")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(viewModel.canConfirm ? Color.blue : Color.gray.opacity(0.3))
                            .foregroundStyle(viewModel.canConfirm ? .white : .secondary)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(!viewModel.canConfirm)
                }
            }
        }
    }
}

// MARK: - Step Indicator

private struct StepIndicator: View {
    let currentStep: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<2, id: \.self) { i in
                HStack(spacing: 6) {
                    Circle()
                        .fill(i <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                    Text(i == 0 ? "Trip Info" : "Add Stops")
                        .font(.caption.bold())
                        .foregroundStyle(i <= currentStep ? .blue : .secondary)
                }
                if i < 1 {
                    Rectangle()
                        .fill(currentStep > i ? Color.blue : Color.gray.opacity(0.3))
                        .frame(height: 2)
                }
            }
        }
    }
}

// MARK: - Trip Metadata Form

private struct TripMetadataForm: View {
    @Bindable var viewModel: TripBuilderViewModel

    let emojis = ["🗺️","✈️","🏖️","🏔️","🌴","🎭","🍜","🚗","🚂","⛵","🏕️","🌆"]
    let colors = ["#3B82F6","#10B981","#F59E0B","#EF4444","#8B5CF6","#EC4899","#14B8A6","#F97316"]

    var body: some View {
        VStack(spacing: 0) {

            // Name
            HStack {
                Text("Trip name").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                TextField("My Trip", text: $viewModel.tripName)
                    .font(.subheadline.bold()).multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            Divider().padding(.leading, 16)

            // Emoji picker
            VStack(alignment: .leading, spacing: 10) {
                Text("Emoji").font(.subheadline).foregroundStyle(.secondary)
                    .padding(.horizontal, 16).padding(.top, 12)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(emojis, id: \.self) { e in
                            Button { viewModel.emoji = e } label: {
                                Text(e).font(.title2)
                                    .frame(width: 44, height: 44)
                                    .background(viewModel.emoji == e ? Color.blue.opacity(0.15) : Color(.secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(viewModel.emoji == e
                                             ? RoundedRectangle(cornerRadius: 10).stroke(.blue, lineWidth: 2)
                                             : nil)
                            }
                        }
                    }
                    .padding(.horizontal, 16).padding(.bottom, 12)
                }
            }
            Divider().padding(.leading, 16)

            // Color picker
            VStack(alignment: .leading, spacing: 10) {
                Text("Color").font(.subheadline).foregroundStyle(.secondary)
                    .padding(.horizontal, 16).padding(.top, 12)
                HStack(spacing: 10) {
                    ForEach(colors, id: \.self) { hex in
                        Button { viewModel.coverColor = hex } label: {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 32, height: 32)
                                .overlay(viewModel.coverColor == hex
                                         ? Circle().stroke(.white, lineWidth: 3)
                                         : nil)
                                .shadow(color: Color(hex: hex).opacity(0.4), radius: 4)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.bottom, 12)
            }
            Divider().padding(.leading, 16)

            // Start date
            DatePicker("Start date", selection: $viewModel.startDate, displayedComponents: .date)
                .font(.subheadline).padding(.horizontal, 16).padding(.vertical, 6)
            Divider().padding(.leading, 16)

            // Number of days
            HStack {
                Text("Number of days").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Stepper("\(viewModel.numberOfDays) day\(viewModel.numberOfDays == 1 ? "" : "s")",
                        value: $viewModel.numberOfDays, in: 1...7)
                    .fixedSize().font(.subheadline.bold())
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            Divider().padding(.leading, 16)

            // Travel mode
            Picker("Travel Mode", selection: $viewModel.travelMode) {
                ForEach(TravelMode.allCases, id: \.self) { m in
                    Label(m.rawValue, systemImage: m.symbolName).tag(m)
                }
            }
            .font(.subheadline).padding(.horizontal, 16).padding(.vertical, 6)
            Divider()
        }
        .background(Color(.systemBackground))
    }
}

#Preview {
    TripBuilderView { trip in print("Created: \(trip.name)") }
}
