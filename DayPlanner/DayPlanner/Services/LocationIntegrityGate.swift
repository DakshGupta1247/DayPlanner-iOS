//
//  LocationIntegrityGate.swift
//  DayPlanner
//
//  FR2 — validates each GPS fix before trusting it.
//  Rejects stale, inaccurate, or physically-impossible "teleport" fixes.
//
//  #if DEBUG: all fixes pass as .trusted so the simulator always works.
//

import CoreLocation

// MARK: - LocationTrust

enum LocationTrust {
    case trusted(CLLocation)
    /// Fix is usable but degraded quality — include reason for UI display
    case degraded(CLLocation, reason: String)
    /// Fix is rejected entirely
    case untrusted(reason: String)
}

// MARK: - LocationIntegrityGate

actor LocationIntegrityGate {

    private static let maxHorizontalAccuracy: Double = 50   // metres
    private static let maxAgeSeconds: Double          = 5   // seconds
    private static let maxSpeedMPS: Double            = 40  // m/s ≈ 144 km/h — teleport threshold

    func validate(_ location: CLLocation, previous: CLLocation?) -> LocationTrust {
        #if DEBUG
        // Simulator always passes — no real GPS chip available
        return .trusted(location)
        #else
        // 1. Accuracy check
        if location.horizontalAccuracy < 0 || location.horizontalAccuracy > Self.maxHorizontalAccuracy {
            return .degraded(location, reason: "Low accuracy (\(Int(location.horizontalAccuracy))m)")
        }

        // 2. Staleness check
        let age = -location.timestamp.timeIntervalSinceNow
        if age > Self.maxAgeSeconds {
            return .untrusted(reason: "Stale fix (\(Int(age))s old)")
        }

        // 3. Teleport check
        if let prev = previous {
            let distance = location.distance(from: prev)
            let timeDelta = location.timestamp.timeIntervalSince(prev.timestamp)
            if timeDelta > 0 {
                let impliedSpeed = distance / timeDelta
                if impliedSpeed > Self.maxSpeedMPS {
                    return .untrusted(reason: "Impossible jump (\(Int(impliedSpeed)) m/s)")
                }
            }
        }

        return .trusted(location)
        #endif
    }
}
