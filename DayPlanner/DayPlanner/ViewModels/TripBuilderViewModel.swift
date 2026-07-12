//
//  TripBuilderViewModel.swift
//  DayPlanner (PlanDay)
//
//  ViewModel for the multi-day "Plan a Trip" builder sheet.
//  Supports both CREATE (default init) and EDIT (init(editing:)) modes.
//  In edit mode the form is pre-filled with the existing trip's data and
//  confirm() preserves the original IDs so TripHistoryService upserts correctly.
//

import MapKit
import Observation
import SwiftUI

@MainActor
@Observable
final class TripBuilderViewModel {

    // MARK: - Trip metadata
    var tripName:    String     = "My Trip"
    var emoji:       String     = "🗺️"
    var coverColor:  String     = "#3B82F6"
    var travelMode:  TravelMode = .driving
    var startDate:   Date       = Calendar.current.startOfDay(for: .now)
    var numberOfDays: Int = 1 {
        didSet {
            while dayStops.count < numberOfDays { dayStops.append([]) }
            if dayStops.count > numberOfDays { dayStops = Array(dayStops.prefix(numberOfDays)) }
            if selectedDayIndex >= numberOfDays { selectedDayIndex = numberOfDays - 1 }
        }
    }

    // MARK: - Per-day state
    var selectedDayIndex: Int = 0
    var dayStops: [[Stop]] = [[]]

    var cameraPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    ))

    var onConfirmed: ((Trip) -> Void)?

    // Kept to preserve the original IDs when editing
    private let existingTripID: UUID?
    private let existingDayIDs: [UUID]

    var isEditing: Bool { existingTripID != nil }

    // MARK: - Computed

    var stops: [Stop] {
        get { dayStops[selectedDayIndex] }
        set { dayStops[selectedDayIndex] = newValue }
    }

    var canConfirm: Bool { dayStops.allSatisfy { !$0.isEmpty } }

    func date(for index: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: index, to: startDate) ?? startDate
    }

    // MARK: - Create mode
    init() {
        self.existingTripID = nil
        self.existingDayIDs = []
    }

    // MARK: - Edit mode — pre-fills all fields from the existing trip
    // Note: Swift does NOT call didSet during init, so setting numberOfDays
    // and dayStops independently here is safe.
    init(editing trip: Trip) {
        self.existingTripID  = trip.id
        self.existingDayIDs  = trip.days.map { $0.id }
        self.tripName        = trip.name
        self.emoji           = trip.emoji
        self.coverColor      = trip.coverColor
        self.travelMode      = trip.travelMode
        self.startDate       = trip.days.first?.date ?? Calendar.current.startOfDay(for: .now)
        self.numberOfDays    = trip.days.count
        self.dayStops        = trip.days.map { $0.stops }
        self.selectedDayIndex = 0
        let coord = trip.days.first?.stops.first.map {
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
        guard !dayStops[selectedDayIndex].contains(where: {
            abs($0.latitude - coord.latitude) < 0.0001 &&
            abs($0.longitude - coord.longitude) < 0.0001
        }) else { return }

        let address = mapItem.addressRepresentations?
            .fullAddress(includingRegion: false, singleLine: true)
            ?? [mapItem.placemark.thoroughfare, mapItem.placemark.locality]
                .compactMap { $0 }.joined(separator: ", ")

        dayStops[selectedDayIndex].append(Stop(
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

    func removeStop(at offsets: IndexSet) { dayStops[selectedDayIndex].remove(atOffsets: offsets) }
    func moveStop(from source: IndexSet, to dest: Int) { dayStops[selectedDayIndex].move(fromOffsets: source, toOffset: dest) }
    func removeStop(_ stop: Stop) { dayStops[selectedDayIndex].removeAll { $0.id == stop.id } }

    func confirm() {
        let days = (0..<numberOfDays).map { i -> DayPlan in
            // Reuse original day IDs when editing so TripHistoryService upserts correctly
            let dayID = i < existingDayIDs.count ? existingDayIDs[i] : UUID()
            return DayPlan(
                id: dayID,
                name: "Day \(i + 1)",
                date: date(for: i),
                stops: dayStops[i],
                travelMode: travelMode
            )
        }
        let trip = Trip(
            id: existingTripID ?? UUID(),
            name: tripName,
            emoji: emoji,
            coverColor: coverColor,
            days: days
        )
        onConfirmed?(trip)
    }

    func reset() {
        tripName = "My Trip"; emoji = "🗺️"; coverColor = "#3B82F6"
        numberOfDays = 1; selectedDayIndex = 0; dayStops = [[]]
        startDate = Calendar.current.startOfDay(for: .now)
    }
}
