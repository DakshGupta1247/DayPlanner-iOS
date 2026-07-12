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
//  ContentView still exists and handles the Onboarding → Home decision
//  for users who complete onboarding, but is now reached via the splash flow.
//

import SwiftUI

@main
struct DayPlannerApp: App {
    var body: some Scene {
        WindowGroup {
            // SplashScreenView is the new root — it handles all routing.
            SplashScreenView()
        }
    }
}
