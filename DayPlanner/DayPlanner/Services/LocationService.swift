//
//  LocationService.swift
//  DayPlanner
//
//  Wraps Apple's CLLocationManager using the modern @Observable pattern.
//
//  What is CLLocationManager?
//  It's Apple's class for accessing the device's GPS. You tell it to start,
//  and it calls your delegate every time the user moves. We wrap it here
//  so the rest of the app never has to deal with the old delegate pattern.
//
//  Why NSObject?
//  CLLocationManagerDelegate requires the conforming type to be an NSObject
//  subclass. @Observable works fine on NSObject subclasses.
//
//  Why nonisolated on delegate methods?
//  CLLocationManagerDelegate isn't declared with @MainActor, so Swift
//  requires delegate methods to be nonisolated. We hop back to @MainActor
//  inside a Task to safely update published properties.
//

import CoreLocation
import Observation

@Observable
@MainActor
final class LocationService: NSObject {

    // The user's most recent GPS position — nil until the first location fix
    var currentLocation: CLLocation? = nil

    // Tracks the app's current location permission state
    var authorizationStatus: CLAuthorizationStatus = .notDetermined

    // The underlying iOS location manager — this is what actually reads the GPS
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        // BestForNavigation = highest accuracy, uses GPS chip directly
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        // Only fire an update if the user has moved >= 10 metres — saves battery
        manager.distanceFilter = 10
        // Read the current permission status (may already be granted from a previous session)
        authorizationStatus = manager.authorizationStatus
    }

    // MARK: - Convenience helpers

    /// True if the user has granted location access (when-in-use or always)
    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    /// True if the user has explicitly denied location access
    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    // MARK: - Public API

    /// Shows the system "Allow Location Access" permission dialog.
    /// Only shown once — if the user denies, they must go to Settings to re-enable.
    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    /// Starts streaming GPS updates. Call after permission is granted.
    func startTracking() {
        manager.startUpdatingLocation()
    }

    /// Stops GPS updates. Call when the navigation screen disappears.
    func stopTracking() {
        manager.stopUpdatingLocation()
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {

    // Fires every time the device's position changes by >= distanceFilter metres
    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        // Hop to @MainActor to safely update the @Observable property
        Task { @MainActor [weak self] in
            self?.currentLocation = location
        }
    }

    // Fires when the user changes their location permission
    // (e.g. taps "Allow" in the system dialog, or revokes in Settings)
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in
            self?.authorizationStatus = status
            // Auto-start tracking as soon as permission is granted
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self?.manager.startUpdatingLocation()
            }
        }
    }

    // Fires if GPS fails (e.g., airplane mode, basement)
    // We ignore silently — the UI handles a nil currentLocation gracefully
    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: Error) { }
}
