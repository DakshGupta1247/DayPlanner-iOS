//
//  TripBuilderViewModel.swift
//  DayPlanner
//
//  ViewModel for the TripBuilder screen.
//  Owns the list of stops the user is building, and handles all
//  add/remove/reorder logic. The View just calls intent functions here.
//
//  Key concept — why pass a callback instead of sharing state?
//  When the user taps "Confirm Trip", we need to send the finished Trip
//  back up to HomeViewModel. We do this with a simple closure (onTripConfirmed)
//  passed in at creation time. This keeps the two ViewModels independent —
//  they don't know about each other, which makes the code easier to maintain.
//

import MapKit
import Observation
import SwiftUI

@MainActor
@Observable
final class TripBuilderViewModel {

    // The stops the user has added so far
    var stops: [Stop] = []

    // The name for this trip, editable by the user
    var tripName: String = "My Day Trip"

    // Currently selected travel mode
    var travelMode: TravelMode = .driving

    // Controls the map camera — updated when a stop is added.
    // MapCameraPosition is the iOS 17+ way to control the map viewport.
    var cameraPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    ))

    // Called when the user confirms the trip — sends result back to HomeViewModel
    var onTripConfirmed: ((Trip) -> Void)?

    // MARK: - Computed

    /// True when there's at least one stop — enables the Confirm button
    var canConfirm: Bool { !stops.isEmpty }

    // MARK: - Intents

    /// Converts an MKMapItem (from search results) into a Stop and adds it
    func addStop(from mapItem: MKMapItem) {
        // location is non-optional CLLocation in iOS 26+
        let coord = mapItem.location.coordinate

        // Avoid exact duplicates — check if coordinate is already in the list
        let alreadyAdded = stops.contains {
            abs($0.latitude - coord.latitude) < 0.0001 &&
            abs($0.longitude - coord.longitude) < 0.0001
        }
        guard !alreadyAdded else { return }

        // Build a human-readable address.
        // addressRepresentations is the new iOS 26 API; fall back to placemark on older OS.
        // addressRepresentations is iOS 26+; the placemark fallback handles older OS.
        let address: String = mapItem.addressRepresentations?
            .fullAddress(includingRegion: false, singleLine: true)
            ?? addressFrom(placemark: mapItem.placemark)

        let stop = Stop(
            name: mapItem.name ?? "Unknown Place",
            address: address,
            latitude: coord.latitude,
            longitude: coord.longitude,
            minutesToSpend: 30 // default — user can change in FR5 Itinerary
        )

        stops.append(stop)

        // Pan the map to show the newly added stop
        cameraPosition = .region(MKCoordinateRegion(
            center: coord,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        ))
    }

    /// Removes a stop at a given index set (called by SwiftUI's onDelete)
    func removeStop(at offsets: IndexSet) {
        stops.remove(atOffsets: offsets)
    }

    /// Reorders stops (called by SwiftUI's onMove / drag-and-drop)
    func moveStop(from source: IndexSet, to destination: Int) {
        stops.move(fromOffsets: source, toOffset: destination)
    }

    /// Removes a specific stop by ID
    func removeStop(_ stop: Stop) {
        stops.removeAll { $0.id == stop.id }
    }

    /// Builds the final Trip and fires the callback to HomeViewModel
    func confirmTrip() {
        let trip = Trip(
            name: tripName,
            date: .now,
            stops: stops,
            travelMode: travelMode
        )
        onTripConfirmed?(trip)
    }

    // Pre-iOS 26 fallback: placemark is deprecated in iOS 26 but still works on older OS.
    private func addressFrom(placemark: MKPlacemark) -> String {
        [placemark.thoroughfare, placemark.locality, placemark.administrativeArea]
            .compactMap { $0 }.joined(separator: ", ")
    }

    /// Resets everything — used when the sheet is dismissed without confirming
    func reset() {
        stops = []
        tripName = "My Day Trip"
    }
}
