//
//  AppEnvironment.swift
//  DayPlanner
//
//  Single place that decides which LocationProviding implementation to use.
//
//  DEBUG builds use GPXReplayProvider so a reviewer can press Run on the
//  simulator and immediately see movement — no real iPhone required.
//
//  Release builds use the real LocationService backed by Core Location.
//

import Foundation

enum AppEnvironment {

    /// The shared location provider for the current build configuration.
    static let locationProvider: LocationProviding = {
        #if DEBUG
        return GPXReplayProvider(gpxFileName: "demo-route", speedMultiplier: 6.0)
        #else
        return LocationService()
        #endif
    }()
}
