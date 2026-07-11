//
//  NavigationService.swift
//  DayPlanner
//
//  Two responsibilities:
//  1. Build Apple Maps URLs to open turn-by-turn navigation for a stop
//  2. Fetch MKDirections step-by-step instructions for in-app display
//
//  Apple Maps URL scheme:
//  maps://?daddr=LAT,LNG&dirflg=d  (d=driving, w=walking, r=transit)
//  This is a free, built-in iOS feature — no API key, no entitlements.
//
//  Why an actor?
//  MKDirections is a network call that can run off the main thread.
//  Using an actor prevents data races if the user taps multiple stops fast.
//

import MapKit

/// A single navigation step (one instruction in the directions list)
struct NavigationStep: Identifiable {
    let id = UUID()
    let instruction: String       // e.g. "Turn left onto Market St"
    let distanceMeters: Double

    var formattedDistance: String {
        distanceMeters < 1000
            ? String(format: "%.0f m", distanceMeters)
            : String(format: "%.1f km", distanceMeters / 1000)
    }
}

actor NavigationService {

    // MARK: - Apple Maps launch

    /// Opens Apple Maps with turn-by-turn directions to the given stop.
    /// Uses the destination coordinate + travel mode.
    ///
    /// Why nonisolated? This function doesn't touch any actor-isolated state —
    /// it just builds a URL and calls UIApplication. Marking it nonisolated
    /// lets callers invoke it without awaiting actor isolation.
    nonisolated func openInAppleMaps(to stop: Stop, mode: TravelMode) {
        let lat = stop.latitude
        let lng = stop.longitude
        // dirflg: d=driving, w=walking, r=transit
        let dirFlag: String
        switch mode {
        case .driving: dirFlag = "d"
        case .walking: dirFlag = "w"
        case .transit: dirFlag = "r"
        }

        // URL-encode the place name for the destination label
        let name = stop.name
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        // Apple Maps URL scheme — works on all iOS devices
        let urlString = "maps://?daddr=\(lat),\(lng)&daddr=\(name)&dirflg=\(dirFlag)"

        guard let url = URL(string: urlString) else { return }

        // UIApplication.shared must be called on the main thread
        DispatchQueue.main.async {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }
    }

    // MARK: - In-app step fetcher

    /// Fetches turn-by-turn step instructions between two stops using MKDirections.
    /// Returns an array of NavigationStep — one per instruction.
    func fetchSteps(from: Stop, to: Stop, mode: TravelMode) async throws -> [NavigationStep] {
        let fromCoord = CLLocationCoordinate2D(latitude: from.latitude, longitude: from.longitude)
        let toCoord   = CLLocationCoordinate2D(latitude: to.latitude,   longitude: to.longitude)

        let fromItem = MKMapItem(placemark: MKPlacemark(coordinate: fromCoord))
        let toItem   = MKMapItem(placemark: MKPlacemark(coordinate: toCoord))

        let request = MKDirections.Request()
        request.source = fromItem
        request.destination = toItem
        request.transportType = mode.mkTransportType
        request.requestsAlternateRoutes = false

        let response = try await MKDirections(request: request).calculate()

        guard let route = response.routes.first else { return [] }

        // MKRoute.steps contains each individual maneuver instruction
        return route.steps.compactMap { step in
            guard !step.instructions.isEmpty else { return nil }
            return NavigationStep(
                instruction: step.instructions,
                distanceMeters: step.distance
            )
        }
    }
}
