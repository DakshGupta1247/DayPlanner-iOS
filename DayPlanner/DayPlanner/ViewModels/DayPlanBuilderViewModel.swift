//
//  DayPlanBuilderViewModel.swift
//  DayPlanner (PlanDay)
//
//  ViewModel for the single-day "Plan a Day" builder sheet.
//  Supports both CREATE (default init) and EDIT (init(editing:)) modes.
//  In edit mode the form is pre-filled with the existing plan's data and
//  confirm() preserves the original ID so TripHistoryService.save() upserts.
//

import MapKit
import Observation
import SwiftUI

@MainActor
@Observable
final class DayPlanBuilderViewModel {

    var name: String
    var date: Date
    var travelMode: TravelMode
    var stops: [Stop]

    var cameraPosition: MapCameraPosition
    var onConfirmed: ((DayPlan) -> Void)?

    // Kept to preserve the original ID when editing
    private let existingID: UUID?

    var isEditing: Bool { existingID != nil }
    var canConfirm: Bool { !stops.isEmpty }

    // MARK: - Create mode
    init() {
        self.existingID = nil
        self.name       = "Day Plan"
        self.date       = Calendar.current.startOfDay(for: .now)
        self.travelMode = .driving
        self.stops      = []
        self.cameraPosition = .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        ))
    }

    // MARK: - Edit mode — pre-fills all fields from the existing plan
    init(editing plan: DayPlan) {
        self.existingID  = plan.id
        self.name        = plan.name
        self.date        = plan.date
        self.travelMode  = plan.travelMode
        self.stops       = plan.stops
        // Centre map on first stop if available, else default SF coords
        let coord = plan.stops.first.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        } ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        self.cameraPosition = .region(MKCoordinateRegion(
            center: coord,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        ))
    }

    // MARK: - Intents

    func addStop(from mapItem: MKMapItem) {
        let coord = mapItem.location.coordinate
        guard !stops.contains(where: {
            abs($0.latitude - coord.latitude) < 0.0001 &&
            abs($0.longitude - coord.longitude) < 0.0001
        }) else { return }

        let address = mapItem.addressRepresentations?
            .fullAddress(includingRegion: false, singleLine: true)
            ?? [mapItem.placemark.thoroughfare, mapItem.placemark.locality]
                .compactMap { $0 }.joined(separator: ", ")

        stops.append(Stop(
            name: mapItem.name ?? "Unknown Place",
            address: address,
            latitude: coord.latitude,
            longitude: coord.longitude
        ))
        cameraPosition = .region(MKCoordinateRegion(
            center: coord,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        ))
    }

    func removeStop(at offsets: IndexSet) { stops.remove(atOffsets: offsets) }
    func moveStop(from source: IndexSet, to dest: Int) { stops.move(fromOffsets: source, toOffset: dest) }
    func removeStop(_ stop: Stop) { stops.removeAll { $0.id == stop.id } }

    // Updates how many minutes the user plans to spend at a specific stop.
    func updateDuration(for stop: Stop, minutes: Int) {
        guard let i = stops.firstIndex(where: { $0.id == stop.id }) else { return }
        stops[i].minutesToSpend = max(5, minutes)
    }

    func confirm() {
        // Use the existing ID when editing so TripHistoryService upserts correctly
        let plan = DayPlan(
            id: existingID ?? UUID(),
            name: name,
            date: date,
            stops: stops,
            travelMode: travelMode
        )
        onConfirmed?(plan)
    }
}
