//
//  RouteService.swift
//  DayPlanner (PlanDay)
//
//  Wraps MKDirections to compute an optimized route for one DayPlan.
//  Also provides a Trip-level convenience that routes the first day
//  (used by legacy callers during the transition).
//

import CoreLocation
import MapKit

// MARK: - RouteLeg

struct RouteLeg {
    let from: Stop
    let to: Stop
    let distanceMeters: Double
    let travelTimeSeconds: Double
    let polyline: MKPolyline
}

// MARK: - ComputedRoute

struct ComputedRoute {
    let orderedStops: [Stop]
    let legs: [RouteLeg]
    let totalDistanceMeters: Double
    let totalTravelTimeSeconds: Double

    var allPolylines: [MKPolyline] { legs.map(\.polyline) }

    var formattedDistance: String {
        let f = MKDistanceFormatter()
        f.unitStyle = .abbreviated
        return f.string(fromDistance: totalDistanceMeters)
    }

    var formattedTravelTime: String {
        let total = Int(totalTravelTimeSeconds)
        let hours = total / 3600
        let mins  = (total % 3600) / 60
        if hours > 0 { return "\(hours)h \(mins)m" }
        return "\(mins) min"
    }
}

// MARK: - RouteService

actor RouteService {

    /// Computes optimized route for a DayPlan.
    /// - Parameters:
    ///   - userDefinedOrder: When true, keeps stops in the exact provided order.
    ///   - startingCoordinate: When provided, used as the invisible origin for the
    ///     first nearest-neighbour pick so Stop #1 is the closest to the user's GPS.
    func computeRoute(for dayPlan: DayPlan,
                      userDefinedOrder: Bool = false,
                      startingCoordinate: CLLocationCoordinate2D? = nil) async throws -> ComputedRoute {
        guard dayPlan.stops.count >= 2 else { throw RouteError.notEnoughStops }
        let ordered = userDefinedOrder
            ? dayPlan.stops
            : nearestNeighborOrder(stops: dayPlan.stops, startingCoordinate: startingCoordinate)
        return try await buildRoute(orderedStops: ordered, travelMode: dayPlan.travelMode)
    }

    /// Computes a route for an explicit ordered stop list, respecting the user's sequence.
    func computeRoute(orderedStops: [Stop], travelMode: TravelMode) async throws -> ComputedRoute {
        guard orderedStops.count >= 2 else { throw RouteError.notEnoughStops }
        return try await buildRoute(orderedStops: orderedStops, travelMode: travelMode)
    }

    /// Optimises and routes a set of remaining stops from a given GPS origin.
    /// Used during live re-optimisation after a stop is reached.
    func computeRoute(remainingStops: [Stop],
                      from startingCoordinate: CLLocationCoordinate2D,
                      travelMode: TravelMode) async throws -> ComputedRoute {
        guard remainingStops.count >= 2 else { throw RouteError.notEnoughStops }
        let ordered = nearestNeighborOrder(stops: remainingStops, startingCoordinate: startingCoordinate)
        return try await buildRoute(orderedStops: ordered, travelMode: travelMode)
    }

    /// Convenience: routes the stops of a Trip (all days combined) for legacy callers.
    func computeRoute(for trip: Trip) async throws -> ComputedRoute {
        guard trip.stops.count >= 2 else { throw RouteError.notEnoughStops }
        let optimized = nearestNeighborOrder(stops: trip.stops, startingCoordinate: nil)
        return try await buildRoute(orderedStops: optimized, travelMode: trip.travelMode)
    }

    // MARK: - Internal

    private func buildRoute(orderedStops: [Stop], travelMode: TravelMode) async throws -> ComputedRoute {
        var legs: [RouteLeg] = []
        for (from, to) in zip(orderedStops.dropLast(), orderedStops.dropFirst()) {
            let leg = try await fetchLeg(from: from, to: to, travelMode: travelMode)
            legs.append(leg)
        }
        return ComputedRoute(
            orderedStops: orderedStops,
            legs: legs,
            totalDistanceMeters: legs.reduce(0) { $0 + $1.distanceMeters },
            totalTravelTimeSeconds: legs.reduce(0) { $0 + $1.travelTimeSeconds }
        )
    }

    /// Nearest-neighbour route optimisation using a binary min-heap.
    /// O(n log n) per step vs O(n²) for the previous linear scan.
    ///
    /// - Parameters:
    ///   - stops: The unordered stops to sequence.
    ///   - startingCoordinate: Optional GPS origin used only for the first pick.
    ///     When nil, the first stop in the input array is used (legacy behaviour).
    private func nearestNeighborOrder(stops: [Stop],
                                      startingCoordinate: CLLocationCoordinate2D?) -> [Stop] {
        guard stops.count > 1 else { return stops }

        var unvisited = stops
        var ordered: [Stop] = []

        // Determine the origin for the first nearest-neighbour pick.
        // If GPS is available, use it as the invisible starting point (Stop #0).
        // Otherwise, pop the first user-added stop as the seed (legacy behaviour).
        var currentCoord: CLLocationCoordinate2D
        if let gps = startingCoordinate {
            currentCoord = gps
            // All stops remain as candidates — none consumed as the "current" yet
        } else {
            let first = unvisited.removeFirst()
            ordered.append(first)
            currentCoord = first.coordinate
        }

        // Build and drain a min-heap at each step to find the nearest unvisited stop.
        // Rebuilding the heap each iteration is O(n log n) total.
        while !unvisited.isEmpty {
            // Key each stop by its Haversine distance from currentCoord
            var heap = MinHeap<(distance: Double, stop: Stop)> { $0.distance < $1.distance }
            for stop in unvisited {
                heap.insert((haversine(from: currentCoord, to: stop.coordinate), stop))
            }
            guard let nearest = heap.extractMin() else { break }
            ordered.append(nearest.stop)
            unvisited.removeAll { $0.id == nearest.stop.id }
            currentCoord = nearest.stop.coordinate
        }

        return ordered
    }

    private func haversine(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let R = 6371000.0
        let lat1 = from.latitude  * .pi / 180
        let lat2 = to.latitude    * .pi / 180
        let dLat = (to.latitude  - from.latitude)  * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180
        let a = sin(dLat/2)*sin(dLat/2) + cos(lat1)*cos(lat2)*sin(dLon/2)*sin(dLon/2)
        return R * 2 * atan2(sqrt(a), sqrt(1 - a))
    }

    private func fetchLeg(from: Stop, to: Stop, travelMode: TravelMode) async throws -> RouteLeg {
        let fromCoord = CLLocationCoordinate2D(latitude: from.latitude, longitude: from.longitude)
        let toCoord   = CLLocationCoordinate2D(latitude: to.latitude,   longitude: to.longitude)
        let request   = MKDirections.Request()
        request.source      = MKMapItem(placemark: MKPlacemark(coordinate: fromCoord))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: toCoord))
        request.transportType = travelMode.mkTransportType
        request.requestsAlternateRoutes = false
        let response = try await MKDirections(request: request).calculate()
        guard let route = response.routes.first else { throw RouteError.noRouteFound }
        return RouteLeg(from: from, to: to,
                        distanceMeters: route.distance,
                        travelTimeSeconds: route.expectedTravelTime,
                        polyline: route.polyline)
    }
}

// MARK: - TravelMode + MKDirections

extension TravelMode {
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
        case .notEnoughStops:        return "Add at least 2 stops to calculate a route."
        case .noRouteFound:          return "No route found between two of your stops."
        case .directionsError(let e): return "Directions error: \(e.localizedDescription)"
        }
    }
}
