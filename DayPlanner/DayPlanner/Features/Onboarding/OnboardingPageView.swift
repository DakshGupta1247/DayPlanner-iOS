//
//  OnboardingPageView.swift
//  DayPlanner
//
//  A single slide in the onboarding carousel.
//  Each page has an SF Symbol icon, a title, and a description.
//  This is a pure "dumb" view — it only displays data passed in from outside.
//

import SwiftUI

/// The data that describes one onboarding slide.
struct OnboardingPage {
    let symbolName: String  // SF Symbol name, e.g. "map.fill"
    let title: String
    let description: String
    let accentColor: Color
}

/// Renders one onboarding slide full-screen.
struct OnboardingPageView: View {

    // The page data to display — passed in by the parent
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 32) {

            Spacer()

            // — Icon —
            // ZStack layers a soft circle background behind the SF Symbol.
            ZStack {
                Circle()
                    .fill(page.accentColor.opacity(0.15))
                    .frame(width: 160, height: 160)

                Image(systemName: page.symbolName)
                    .font(.system(size: 72, weight: .semibold))
                    .foregroundStyle(page.accentColor)
            }

            // — Text —
            VStack(spacing: 12) {
                Text(page.title)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
            Spacer() // extra spacer so content sits above the button area
        }
    }
}

#Preview {
    OnboardingPageView(page: OnboardingPage(
        symbolName: "map.fill",
        title: "Plan Your Day",
        description: "Add all the places you want to visit and let DayPlanner build the perfect route.",
        accentColor: .blue
    ))
}
