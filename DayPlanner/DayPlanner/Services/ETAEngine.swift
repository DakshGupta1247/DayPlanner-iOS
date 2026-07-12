//
//  ETAEngine.swift
//  DayPlanner
//
//  FR3 — real-time ETA calculation using exponential moving average speed.
//
//  Algorithm:
//  - EMA: smoothedSpeed = 0.3 * newSpeed + 0.7 * smoothedSpeed
//  - Speed source: CLLocation.speed when >= 0, else Haversine / timeDelta
//  - Returns nil until fixCount >= 2 or speed >= 0.5 m/s (warmup guard)
//  - Closing-time verdict: compares arrivalTime against stop.openUntil
//

import CoreLocation
import Foundation

// MARK: - ETAResult

struct ETAResult {
    let durationSeconds: Double
    let arrivalTime: Date
    let distanceMeters: Double
}

// MARK: - ClosingTimeVerdict

enum ClosingTimeVerdict {
    case makeIt
    case cuttingClose   // arrives within 15 minutes of closing
    case wontMakeIt
    case noClosingTime
}

// MARK: - ETAEngine

final class ETAEngine {

    private let alpha = 0.3
    private var smoothedSpeed: Double = 0
    private var fixCount = 0
    private var lastLocation: CLLocation? = nil

    // MARK: - Update with new GPS fix

    func update(newLocation: CLLocation) {
        defer {
            lastLocation = newLocation
            fixCount += 1
        }

        let rawSpeed: Double
        if newLocation.speed >= 0 {
            rawSpeed = newLocation.speed
        } else if let prev = lastLocation {
            let timeDelta = newLocation.timestamp.timeIntervalSince(prev.timestamp)
            guard timeDelta > 0 else { return }
            rawSpeed = newLocation.distance(from: prev) / timeDelta
        } else {
            return
        }

        smoothedSpeed = alpha * rawSpeed + (1 - alpha) * smoothedSpeed
    }

    // MARK: - ETA to destination

    /// Returns nil during warmup (fewer than 2 fixes or speed < 0.5 m/s).
    func eta(to destination: CLLocationCoordinate2D,
             from origin: CLLocationCoordinate2D) -> ETAResult? {
        guard fixCount >= 2, smoothedSpeed >= 0.5 else { return nil }

        let distance = haversine(from: origin, to: destination)
        let duration = distance / smoothedSpeed
        let arrival  = Date().addingTimeInterval(duration)

        return ETAResult(durationSeconds: duration,
                         arrivalTime: arrival,
                         distanceMeters: distance)
    }

    // MARK: - Closing time verdict

    func verdict(eta: ETAResult, stop: Stop) -> ClosingTimeVerdict {
        guard let closingTime = stop.openUntil else { return .noClosingTime }
        let margin = closingTime.timeIntervalSince(eta.arrivalTime)
        if margin < 0        { return .wontMakeIt }
        if margin < 15 * 60  { return .cuttingClose }
        return .makeIt
    }

    // MARK: - Reset (call when advancing to next stop)

    func reset() {
        smoothedSpeed = 0
        fixCount = 0
        lastLocation = nil
    }

    // MARK: - Haversine

    private func haversine(from: CLLocationCoordinate2D,
                           to: CLLocationCoordinate2D) -> Double {
        let R = 6371000.0
        let lat1 = from.latitude  * .pi / 180
        let lat2 = to.latitude    * .pi / 180
        let dLat = (to.latitude  - from.latitude)  * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180
        let a = sin(dLat/2)*sin(dLat/2) + cos(lat1)*cos(lat2)*sin(dLon/2)*sin(dLon/2)
        return R * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
}
