//
//  RouteService.swift
//  DayPlanner
//
//  Wraps Apple's MKDirections API to calculate routes between stops.
//
//  Key concepts:
//  - MKDirections: Apple's free routing API (no API key). Given two map items,
//    it returns a route with distance, travel time, and step-by-step polyline.
//  - We calculate routes between consecutive stops (A→B, B→C, C→D etc.)
//    NOT between every possible pair, which would be too many requests.
//  - actor keyword: an actor is like a class but Swift guarantees only one
//    piece of code can access it at a time. This prevents data races when
//    multiple async tasks run in parallel.
//

import MapKit

/// The result of computing one leg of the route (one stop to the next).
struct RouteLeg {
    let from: Stop
    let to: Stop
    let distanceMeters: Double
    let travelTimeSeconds: Double
    let polyline: MKPolyline   // the actual path drawn on the map
}

/// Holds the complete computed route across all stops.
struct ComputedRoute {
    let orderedStops: [Stop]       // stops in optimized visit order
    let legs: [RouteLeg]           // one leg per consecutive stop pair
    let totalDistanceMeters: Double
    let totalTravelTimeSeconds: Double

    // Convenience: all polylines joined for easy map rendering
    var allPolylines: [MKPolyline] { legs.map(\.polyline) }

    // Human-readable total distance, e.g. "12.4 km"
    var formattedDistance: String {
        let formatter = MKDistanceFormatter()
        formatter.unitStyle = .abbreviated
        return formatter.string(fromDistance: totalDistanceMeters)
    }

    // Human-readable travel time, e.g. "1h 23m"
    var formattedTravelTime: String {
        let total = Int(totalTravelTimeSeconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes) min"
    }
}

actor RouteService {

    // MARK: - Public API

    /// Computes the full optimized route for a trip.
    /// Step 1: reorder stops with nearest-neighbor algorithm.
    /// Step 2: call MKDirections for each consecutive pair.
    func computeRoute(for trip: Trip) async throws -> ComputedRoute {
        guard trip.stops.count >= 2 else {
            throw RouteError.notEnoughStops
        }

        // Step 1 — reorder stops using nearest-neighbor greedy algorithm
        let optimized = nearestNeighborOrder(stops: trip.stops)

        // Step 2 — fetch a route leg for each consecutive stop pair
        // We use a TaskGroup so legs can be fetched in parallel for speed.
        var legs: [RouteLeg] = []

        // Build pairs: [(stop0,stop1), (stop1,stop2), (stop2,stop3) ...]
        let pairs = zip(optimized.dropLast(), optimized.dropFirst())

        for (from, to) in pairs {
            let leg = try await fetchLeg(from: from, to: to, travelMode: trip.travelMode)
            legs.append(leg)
        }

        let totalDistance = legs.reduce(0) { $0 + $1.distanceMeters }
        let totalTime     = legs.reduce(0) { $0 + $1.travelTimeSeconds }

        return ComputedRoute(
            orderedStops: optimized,
            legs: legs,
            totalDistanceMeters: totalDistance,
            totalTravelTimeSeconds: totalTime
        )
    }

    // MARK: - Nearest-Neighbor Algorithm
    //
    // How it works:
    // 1. Start with the first stop in the list as "current"
    // 2. Find the unvisited stop with the shortest straight-line distance
    // 3. Move there, mark it visited
    // 4. Repeat until all stops are visited
    //
    // This is a "greedy" algorithm — it always picks the locally best choice.
    // It doesn't guarantee the globally perfect route, but it's fast and
    // produces a good result for a typical day trip (< 10 stops).
    //
    private func nearestNeighborOrder(stops: [Stop]) -> [Stop] {
        guard stops.count > 1 else { return stops }

        var unvisited = stops           // stops not yet added to route
        var ordered: [Stop] = []

        // Start from the first stop (index 0 = user's starting point)
        var current = unvisited.removeFirst()
        ordered.append(current)

        while !unvisited.isEmpty {
            // Find the closest unvisited stop using Haversine distance
            let nearest = unvisited.min(by: {
                haversine(from: current.coordinate, to: $0.coordinate) <
                haversine(from: current.coordinate, to: $1.coordinate)
            })!

            ordered.append(nearest)
            unvisited.removeAll { $0.id == nearest.id }
            current = nearest
        }

        return ordered
    }

    // MARK: - Haversine Distance
    //
    // Haversine calculates the straight-line ("as the crow flies") distance
    // between two GPS coordinates on a sphere (the Earth).
    // We use this for the optimization step — it's instant, no network needed.
    // MKDirections gives us the real road distance after optimization.
    //
    private func haversine(from: CLLocationCoordinate2D,
                           to: CLLocationCoordinate2D) -> Double {
        let R = 6371000.0  // Earth radius in metres
        let lat1 = from.latitude  * .pi / 180
        let lat2 = to.latitude    * .pi / 180
        let dLat = (to.latitude  - from.latitude)  * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180

        let a = sin(dLat/2) * sin(dLat/2)
              + cos(lat1) * cos(lat2) * sin(dLon/2) * sin(dLon/2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))

        return R * c
    }

    // MARK: - MKDirections fetch

    /// Calls MKDirections to get real road distance + travel time + polyline
    /// for a single stop-to-stop leg.
    private func fetchLeg(from: Stop, to: Stop,
                          travelMode: TravelMode) async throws -> RouteLeg {
        // Extract raw coordinate values (Doubles) inside the actor — no isolation issue.
        // Then build CLLocationCoordinate2D from them (a plain struct, Sendable).
        let fromCoord = CLLocationCoordinate2D(latitude: from.latitude, longitude: from.longitude)
        let toCoord   = CLLocationCoordinate2D(latitude: to.latitude,   longitude: to.longitude)
        let transport = travelMode.mkTransportType   // read nonisolated property here

        // Build MKMapItems using the new iOS 26 init; fall back to placemark for older OS
        let fromItem = MKMapItem(placemark: MKPlacemark(coordinate: fromCoord))
        let toItem   = MKMapItem(placemark: MKPlacemark(coordinate: toCoord))

        // Configure the directions request
        let request = MKDirections.Request()
        request.source = fromItem
        request.destination = toItem
        request.transportType = transport
        request.requestsAlternateRoutes = false  // we just need the fastest

        let directions = MKDirections(request: request)

        do {
            let response = try await directions.calculate()
            // .routes is sorted best-first; we take the first one
            guard let route = response.routes.first else {
                throw RouteError.noRouteFound
            }

            return RouteLeg(
                from: from,
                to: to,
                distanceMeters: route.distance,
                travelTimeSeconds: route.expectedTravelTime,
                polyline: route.polyline
            )
        } catch {
            throw RouteError.directionsError(error)
        }
    }
}

// MARK: - TravelMode extension

extension TravelMode {
    /// Maps our TravelMode enum to MapKit's transport type.
    /// nonisolated: enum is a value type, safe to read from any actor context.
    nonisolated var mkTransportType: MKDirectionsTransportType {
        switch self {
        case .driving: return .automobile
        case .walking: return .walking
        case .transit: return .transit
        }
    }
}

// MARK: - Errors

enum RouteError: LocalizedError {
    case notEnoughStops
    case noRouteFound
    case directionsError(Error)

    var errorDescription: String? {
        switch self {
        case .notEnoughStops:
            return "Add at least 2 stops to calculate a route."
        case .noRouteFound:
            return "No route found between two of your stops."
        case .directionsError(let e):
            return "Directions error: \(e.localizedDescription)"
        }
    }
}
