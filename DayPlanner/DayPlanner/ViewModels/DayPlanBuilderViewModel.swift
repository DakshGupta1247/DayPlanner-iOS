//
//  DayPlanBuilderViewModel.swift
//  DayPlanner (PlanDay)
//
//  ViewModel for the single-day "Plan a Day" builder sheet.
//  Creates a standalone DayPlan and fires onConfirmed when done.
//

import MapKit
import Observation
import SwiftUI

@MainActor
@Observable
final class DayPlanBuilderViewModel {

    var name: String = "Day Plan"
    var date: Date = Calendar.current.startOfDay(for: .now)
    var travelMode: TravelMode = .driving
    var stops: [Stop] = []

    var cameraPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    ))

    var onConfirmed: ((DayPlan) -> Void)?

    var canConfirm: Bool { !stops.isEmpty }

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

    func confirm() {
        let plan = DayPlan(name: name, date: date, stops: stops, travelMode: travelMode)
        onConfirmed?(plan)
    }

    func reset() {
        name = "Day Plan"
        date = Calendar.current.startOfDay(for: .now)
        stops = []
        travelMode = .driving
    }
}
