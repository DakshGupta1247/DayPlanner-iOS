//
//  OnboardingView.swift
//  DayPlanner
//
//  The full onboarding flow: a 3-page swipeable carousel + "Get Started" button.
//
//  Key concepts used here:
//  - TabView with .tabViewStyle(.page) → gives us the swipeable dot-indicator carousel
//  - @AppStorage → reads/writes a value in UserDefaults with one line of code
//  - @State → local view state (which page we're on)
//

import SwiftUI

struct OnboardingView: View {

    // @AppStorage is SwiftUI's wrapper around UserDefaults.
    // When we set hasCompletedOnboarding = true, it is immediately saved to disk.
    // ContentView reads this same key to decide which screen to show.
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    // Tracks which slide the user is currently viewing (0, 1, or 2).
    @State private var currentPage = 0

    // The three slides we'll show. Defined once, passed to OnboardingPageView.
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            symbolName: "map.fill",
            title: "Plan Your Day",
            description: "Add all the places you want to visit — shops, restaurants, parks, anywhere.",
            accentColor: .blue
        ),
        OnboardingPage(
            symbolName: "arrow.triangle.turn.up.right.diamond.fill",
            title: "Optimal Route",
            description: "DayPlanner automatically orders your stops to save you time and travel.",
            accentColor: .green
        ),
        OnboardingPage(
            symbolName: "clock.fill",
            title: "Live Itinerary",
            description: "See your full day as a timeline with arrival times and turn-by-turn navigation.",
            accentColor: .orange
        )
    ]

    var body: some View {
        ZStack(alignment: .bottom) {

            // — Carousel —
            // TabView in .page style renders each child as a swipeable page.
            // The $currentPage binding keeps our @State in sync with what's visible.
            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { index in
                    OnboardingPageView(page: pages[index])
                        .tag(index) // tag connects this page to the selection binding
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always)) // shows the dot indicators
            .animation(.easeInOut, value: currentPage)

            // — Bottom button area —
            VStack(spacing: 0) {
                // Show "Next" on the first two pages, "Get Started" on the last.
                if currentPage < pages.count - 1 {
                    Button {
                        // Advance to the next page with animation
                        withAnimation {
                            currentPage += 1
                        }
                    } label: {
                        Text("Next")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    // "Skip" lets the user jump straight to the end
                    Button("Skip") {
                        withAnimation {
                            currentPage = pages.count - 1
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

                } else {
                    // Last page — tapping this writes true to UserDefaults,
                    // which triggers ContentView to swap to HomeView.
                    Button {
                        hasCompletedOnboarding = true
                    } label: {
                        Text("Get Started")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48) // keep clear of the home indicator
        }
    }
}

#Preview {
    OnboardingView()
}
