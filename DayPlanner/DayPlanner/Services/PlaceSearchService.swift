//
//  PlaceSearchService.swift
//  DayPlanner
//
//  Wraps Apple's MKLocalSearch in a clean async/await interface.
//
//  Why a separate Service file?
//  Services handle external APIs and frameworks (MapKit here).
//  Neither the View nor the ViewModel should talk to MKLocalSearch directly —
//  that's the Service's job. This keeps ViewModels testable and focused.
//
//  Key concepts:
//  - MKLocalSearch: Apple's free place search API, no API key needed
//  - Task cancellation: we cancel the previous search task before starting a
//    new one, so rapid typing doesn't fire 10 network requests
//  - Debounce: we wait 400ms before actually hitting the network, so we only
//    search when the user pauses typing
//  - @MainActor: all property mutations happen on the main thread, which is
//    required because SwiftUI observes these properties from the main thread
//

import MapKit
import Observation

@MainActor
@Observable
final class PlaceSearchService {

    // The results from the last completed search.
    // Empty array when no search has been done or the query was cleared.
    private(set) var results: [MKMapItem] = []

    // True while a network request is in flight — used to show a spinner
    private(set) var isLoading = false

    // Holds a reference to the current search task so we can cancel it
    // the moment a new character is typed in the search field
    private var currentTask: Task<Void, Never>?

    /// Start a debounced place search for `query`.
    /// Cancels any in-flight search before starting a new one.
    func search(query: String) {
        // Cancel whatever was running before
        currentTask?.cancel()

        // If the field is empty, clear results and stop
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []
            return
        }

        currentTask = Task {
            // Debounce: wait 400ms. If the user types again before 400ms,
            // this task gets cancelled and the sleep throws CancellationError,
            // which causes execution to stop at the try? line below.
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }

            isLoading = true

            // Build the search request
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            // Search for both POIs (restaurants, parks…) and addresses
            request.resultTypes = [.pointOfInterest, .address]

            do {
                let search = MKLocalSearch(request: request)
                let response = try await search.start()
                guard !Task.isCancelled else { return }
                // Limit to top 8 results to keep the list manageable
                results = Array(response.mapItems.prefix(8))
            } catch {
                // Network error or no results — just show an empty list
                if !Task.isCancelled { results = [] }
            }

            isLoading = false
        }
    }

    /// Cancels any pending search and clears the results list.
    func clear() {
        currentTask?.cancel()
        results = []
        isLoading = false
    }
}
