//
//  DayPlannerApp.swift
//  DayPlanner (PlanDay)
//
//  The @main entry point — the very first code that runs when the app launches.
//
//  LAUNCH FLOW:
//  DayPlannerApp → SplashScreenView (always, every launch)
//                     ↓ after 2 seconds
//              hasSeenWelcomeScreen?
//                YES → HomeView   (returning user)
//                NO  → WelcomeScreenView → HomeView  (first launch)
//
//  On every launch we also ask for notification permission (iOS only prompts
//  the user once; after that this call just checks the cached answer).
//

import SwiftUI

@main
struct DayPlannerApp: App {

    init() {
        // Request notification permission early so the system prompt
        // appears on first launch. Subsequent launches are a no-op.
        Task { await NotificationService.shared.requestPermission() }
    }

    var body: some Scene {
        WindowGroup {
            // SplashScreenView is the new root — it handles all routing.
            SplashScreenView()
        }
    }
}
