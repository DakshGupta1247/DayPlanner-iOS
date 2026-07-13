//
//  LocationService.swift
//  DayPlanner
//
//  Wraps Apple's CLLocationManager using the modern @Observable pattern.
//  Each raw GPS fix is validated by LocationIntegrityGate before being emitted
//  on trustedLocationStream — the stream callers should prefer over currentLocation.
//

import CoreLocation
import Observation

@Observable
@MainActor
final class LocationService: NSObject, LocationProviding {

    // The user's most recent raw GPS position — nil until the first location fix
    var currentLocation: CLLocation? = nil

    // Tracks the app's current location permission state
    var authorizationStatus: CLAuthorizationStatus = .notDetermined

    // Latest trust verdict — drives the GPS trust chip in LiveNavigationView
    var latestTrust: LocationTrust? = nil

    // True once trustedLocationStream has emitted at least one location.
    // RouteOptimizerViewModel uses this to know when GPS is ready.
    var hasReceivedFirstFix: Bool = false

    // Stream of validated (trusted + degraded) locations for navigation consumers
    private(set) var trustedLocationStream: AsyncStream<CLLocation>
    private var trustedLocationContinuation: AsyncStream<CLLocation>.Continuation?

    private let gate = LocationIntegrityGate()
    private var previousLocation: CLLocation? = nil

    // The underlying iOS location manager — this is what actually reads the GPS
    private let manager = CLLocationManager()

    override init() {
        var continuation: AsyncStream<CLLocation>.Continuation?
        trustedLocationStream = AsyncStream { continuation = $0 }
        trustedLocationContinuation = continuation
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = 10
        authorizationStatus = manager.authorizationStatus
    }

    // MARK: - Convenience helpers

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    // MARK: - Public API

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func startTracking() {
        manager.startUpdatingLocation()
    }

    func stopTracking() {
        manager.stopUpdatingLocation()
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            // Always update raw currentLocation for legacy callers
            self.currentLocation = location

            // Validate through the integrity gate
            let prev = self.previousLocation
            let trust = await self.gate.validate(location, previous: prev)
            self.latestTrust = trust
            self.previousLocation = location

            // Emit trusted and degraded fixes; drop untrusted ones
            switch trust {
            case .trusted(let loc), .degraded(let loc, _):
                self.hasReceivedFirstFix = true
                self.trustedLocationContinuation?.yield(loc)
            case .untrusted:
                break
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in
            self?.authorizationStatus = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self?.manager.startUpdatingLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: Error) { }
}
