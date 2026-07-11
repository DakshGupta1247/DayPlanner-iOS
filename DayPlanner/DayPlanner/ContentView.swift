//
//  ContentView.swift
//  DayPlanner
//
//  This is the app's root view — the "traffic cop" that decides what to show.
//
//  Logic:
//  - First launch ever → show OnboardingView
//  - Every launch after → show HomeView
//
//  How it works:
//  @AppStorage("hasCompletedOnboarding") reads the same UserDefaults key
//  that OnboardingView writes to when the user taps "Get Started".
//  Because it's @AppStorage, SwiftUI automatically re-renders this view
//  the moment the value changes — so the transition to HomeView is instant.
//

import SwiftUI

struct ContentView: View {

    // Mirrors the UserDefaults value written by OnboardingView.
    // false  → user hasn't finished onboarding yet
    // true   → user has completed onboarding, go straight to home
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        // A simple if/else: show one view or the other based on the flag.
        // The .transition + .animation make the swap look smooth.
        Group {
            if hasCompletedOnboarding {
                HomeView()
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: hasCompletedOnboarding)
    }
}

#Preview {
    ContentView()
}
