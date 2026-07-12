//
//  LocationIntegrityGate.swift
//  DayPlanner
//
//  FR2 — validates each GPS fix before trusting it.
//  Rejects stale, inaccurate, or physically-impossible "teleport" fixes.
//
//  ROOT CAUSE FIX (real-device GPS fallback always triggering):
//  On a real device Core Location often delivers a CACHED fix immediately when
//  startUpdatingLocation() is called. That cached fix can be 10–60 seconds old,
//  which caused the old 5-second staleness check to reject it as .untrusted,
//  meaning trustedLocationStream never emitted anything before optimise() ran.
//
//  Fix: when previous == nil (first fix ever), skip staleness AND teleport checks.
//  We still reject completely invalid coordinates (0,0 or negative accuracy).
//  Strict checks only apply from the second fix onward.
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

    private static let maxHorizontalAccuracy: Double = 100  // metres — relaxed for first fix
    private static let maxAgeSeconds: Double          = 30  // seconds — first fix may be cached
    private static let strictMaxAccuracy: Double      = 50  // metres — applied from 2nd fix onward
    private static let strictMaxAgeSeconds: Double    = 5   // seconds — applied from 2nd fix onward
    private static let maxSpeedMPS: Double            = 40  // m/s — teleport threshold

    func validate(_ location: CLLocation, previous: CLLocation?) -> LocationTrust {
        #if DEBUG
        return .trusted(location)
        #else
        let isFirstFix = (previous == nil)

        // Always reject completely invalid coordinates
        guard location.horizontalAccuracy >= 0 else {
            return .untrusted(reason: "Invalid accuracy")
        }
        let coord = location.coordinate
        guard coord.latitude != 0 || coord.longitude != 0 else {
            return .untrusted(reason: "Null island coordinate")
        }

        if isFirstFix {
            // FIRST FIX — lenient checks only.
            // Core Location may deliver a cached fix that is minutes old but still
            // geographically correct. Accept it as long as accuracy is reasonable.
            let accuracy = location.horizontalAccuracy
            if accuracy > Self.maxHorizontalAccuracy {
                return .degraded(location, reason: "Low accuracy (\(Int(accuracy))m)")
            }
            // No staleness or teleport check on first fix — no baseline to compare against
            return .trusted(location)
        }

        // SUBSEQUENT FIXES — strict checks

        // 1. Accuracy check
        if location.horizontalAccuracy > Self.strictMaxAccuracy {
            return .degraded(location, reason: "Low accuracy (\(Int(location.horizontalAccuracy))m)")
        }

        // 2. Staleness check
        let age = -location.timestamp.timeIntervalSinceNow
        if age > Self.strictMaxAgeSeconds {
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
