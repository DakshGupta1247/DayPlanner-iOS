//
//  LocationProviding.swift
//  DayPlanner
//
//  Protocol that abstracts GPS location delivery.
//  LocationService (real GPS on device) and GPXReplayProvider (simulator demo)
//  both conform — callers never need to know which one they're talking to.
//

import CoreLocation

protocol LocationProviding: AnyObject {

    /// Validated, trusted location fixes — prefer this over polling currentLocation.
    var trustedLocationStream: AsyncStream<CLLocation> { get }

    /// Most recent location fix; nil before the first fix arrives.
    var currentLocation: CLLocation? { get }

    /// True once trustedLocationStream has emitted at least one fix.
    var hasReceivedFirstFix: Bool { get }

    /// True when the user has explicitly denied location permission.
    var isDenied: Bool { get }

    /// True when location permission is currently granted.
    var isAuthorized: Bool { get }

    /// Latest trust verdict — drives the GPS trust chip in LiveNavigationView.
    var latestTrust: LocationTrust? { get }

    /// Request permission from the user. No-op if already granted or denied.
    func requestPermission()

    /// Begin delivering location fixes.
    func startTracking()

    /// Stop delivering location fixes.
    func stopTracking()
}
