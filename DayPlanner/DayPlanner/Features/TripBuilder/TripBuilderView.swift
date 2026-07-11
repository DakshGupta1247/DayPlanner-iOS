//
//  TripBuilderView.swift
//  DayPlanner
//
//  The full "Plan Your Day" sheet where users search for places and build
//  their trip. Presented as a sheet from HomeView.
//
//  Layout:
//  - Top: search bar
//  - Middle: either search results list OR map + stops list (when stops added)
//  - Bottom: Confirm Trip button
//
//  Key SwiftUI concepts used:
//  - @FocusState: programmatically controls keyboard focus on the search field
//  - Map with Marker: iOS 17's new declarative MapKit API
//  - List with onDelete + onMove: drag-to-reorder and swipe-to-delete built in
//

import MapKit
import SwiftUI

struct TripBuilderView: View {

    // The ViewModel manages all state and logic for this sheet
    @State private var viewModel: TripBuilderViewModel

    // Manages the search logic (debounced MKLocalSearch calls)
    @State private var searchService = PlaceSearchService()

    // The text currently typed in the search field
    @State private var searchText = ""

    // True while the search field is active / keyboard is showing
    @FocusState private var isSearchFocused: Bool

    // Lets us close this sheet from inside the view
    @Environment(\.dismiss) private var dismiss

    // Initializer — receives the callback from HomeView
    init(onTripConfirmed: @escaping (Trip) -> Void) {
        let vm = TripBuilderViewModel()
        vm.onTripConfirmed = onTripConfirmed
        _viewModel = State(initialValue: vm)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // — Search bar —
                SearchBar(
                    text: $searchText,
                    isFocused: $isSearchFocused,
                    onClear: {
                        searchText = ""
                        searchService.clear()
                        isSearchFocused = false
                    }
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider()

                // — Main content area —
                // Show search results when typing, map+stops otherwise
                if isSearchFocused || !searchText.isEmpty {
                    SearchResultsSection(
                        searchService: searchService,
                        searchText: searchText,
                        viewModel: viewModel,
                        onAdd: { mapItem in
                            viewModel.addStop(from: mapItem)
                            // After adding, dismiss keyboard and clear search
                            searchText = ""
                            searchService.clear()
                            isSearchFocused = false
                        }
                    )
                } else {
                    TripMapAndStopsSection(viewModel: viewModel)
                }

                Divider()

                // — Bottom action area —
                BottomBar(
                    viewModel: viewModel,
                    onConfirm: {
                        viewModel.confirmTrip()
                        dismiss()
                    },
                    onCancel: { dismiss() }
                )
                .padding(16)
            }
            .navigationTitle("Plan Your Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        // Fire the search whenever searchText changes
        .onChange(of: searchText) { _, newValue in
            searchService.search(query: newValue)
        }
    }
}

// MARK: - Search Bar

private struct SearchBar: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search for a place...", text: $text)
                .focused(isFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()

            if !text.isEmpty {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Search Results

private struct SearchResultsSection: View {
    let searchService: PlaceSearchService
    let searchText: String
    let viewModel: TripBuilderViewModel
    let onAdd: (MKMapItem) -> Void

    var body: some View {
        Group {
            if searchService.isLoading {
                // Spinner while search is in flight
                VStack {
                    Spacer()
                    ProgressView("Searching...")
                    Spacer()
                }
            } else if searchService.results.isEmpty && !searchText.isEmpty {
                // No results state
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No results for \"\(searchText)\"")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                // Results list
                List(searchService.results, id: \.self) { mapItem in
                    // Check if this place is already in the stop list
                    let coord = mapItem.location.coordinate
                    let isAdded = viewModel.stops.contains {
                        abs($0.latitude - coord.latitude) < 0.0001
                    }
                    PlaceSearchResultRow(
                        mapItem: mapItem,
                        onAdd: { onAdd(mapItem) },
                        isAdded: isAdded
                    )
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                }
                .listStyle(.plain)
            }
        }
    }
}

// MARK: - Map + Stops List

private struct TripMapAndStopsSection: View {
    @Bindable var viewModel: TripBuilderViewModel

    var body: some View {
        if viewModel.stops.isEmpty {
            // Empty state when no stops added yet
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "magnifyingglass.circle")
                    .font(.system(size: 56))
                    .foregroundStyle(.blue.opacity(0.5))
                Text("Search for places to visit")
                    .font(.headline)
                Text("Type in the search bar above\nto find and add stops to your trip.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Spacer()
            }
        } else {
            VStack(spacing: 0) {
                // — Mini map showing all stop pins —
                // Map with MapContentBuilder is the iOS 17+ declarative API.
                // We bind to cameraPosition so the map pans when stops are added.
                Map(position: $viewModel.cameraPosition) {
                    ForEach(Array(viewModel.stops.enumerated()), id: \.element.id) { index, stop in
                        Annotation("", coordinate: stop.coordinate) {
                            StopPin(number: index + 1)
                        }
                    }
                }
                .frame(height: 200)

                Divider()

                // — Trip name field —
                HStack {
                    Text("Trip name:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("My Day Trip", text: $viewModel.tripName)
                        .font(.subheadline.bold())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider()

                // — Ordered stop list with drag-to-reorder + swipe-to-delete —
                List {
                    ForEach(Array(viewModel.stops.enumerated()), id: \.element.id) { index, stop in
                        StopRow(number: index + 1, stop: stop) {
                            viewModel.removeStop(stop)
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                    .onDelete { offsets in viewModel.removeStop(at: offsets) }
                    .onMove  { source, dest in viewModel.moveStop(from: source, to: dest) }
                }
                .listStyle(.plain)
                // EditButton in the toolbar enables the drag handles
                .toolbar { EditButton() }
            }
        }
    }
}

// MARK: - Stop Pin (map annotation)

private struct StopPin: View {
    let number: Int

    var body: some View {
        ZStack {
            Circle()
                .fill(.blue)
                .frame(width: 30, height: 30)
                .shadow(radius: 3)
            Text("\(number)")
                .font(.caption.bold())
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Stop Row (in the list)

private struct StopRow: View {
    let number: Int
    let stop: Stop
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Numbered badge
            ZStack {
                Circle()
                    .fill(.blue)
                    .frame(width: 28, height: 28)
                Text("\(number)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(stop.name)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Text(stop.address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Swipe-to-delete is provided by onDelete above,
            // but this button gives an extra visible remove option
            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red.opacity(0.8))
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Bottom Bar

private struct BottomBar: View {
    let viewModel: TripBuilderViewModel
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            // Stop count summary
            if !viewModel.stops.isEmpty {
                Text("\(viewModel.stops.count) stop\(viewModel.stops.count == 1 ? "" : "s") added")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Confirm button — disabled until at least 1 stop is added
            Button(action: onConfirm) {
                Text(viewModel.canConfirm ? "Confirm Trip" : "Add at least one stop")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.canConfirm ? Color.blue : Color.gray.opacity(0.3))
                    .foregroundStyle(viewModel.canConfirm ? .white : .secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(!viewModel.canConfirm)
        }
    }
}

#Preview {
    TripBuilderView { trip in
        print("Trip confirmed: \(trip.name) with \(trip.stops.count) stops")
    }
}
