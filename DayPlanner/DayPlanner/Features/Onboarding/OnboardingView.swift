//
//  OnboardingView.swift
//  DayPlanner (PlanDay)
//
//  4-page onboarding carousel.
//  Pages 1–3: feature highlights.
//  Page 4: name capture — renames the default "Me" profile so the
//           greeting on Home says the user's actual name from day one.
//

import SwiftUI

struct OnboardingView: View {

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentPage = 0
    @State private var nameInput   = ""
    @FocusState private var nameFocused: Bool

    private let featurePages: [OnboardingPage] = [
        OnboardingPage(
            symbolName: "map.fill",
            title: "Plan Your Day",
            description: "Add all the places you want to visit — shops, restaurants, parks, anywhere.",
            accentColor: .blue
        ),
        OnboardingPage(
            symbolName: "arrow.triangle.turn.up.right.diamond.fill",
            title: "Optimal Route",
            description: "PlanDay automatically orders your stops to save you time and travel.",
            accentColor: .green
        ),
        OnboardingPage(
            symbolName: "clock.fill",
            title: "Live Itinerary",
            description: "See your full day as a timeline with arrival times and turn-by-turn navigation.",
            accentColor: .orange
        )
    ]

    // Total pages = 3 feature slides + 1 name slide
    private var totalPages: Int { featurePages.count + 1 }
    private var isNamePage: Bool { currentPage == featurePages.count }
    private var isLastPage: Bool { currentPage == totalPages - 1 }

    var body: some View {
        ZStack(alignment: .bottom) {

            // — Carousel —
            TabView(selection: $currentPage) {
                ForEach(featurePages.indices, id: \.self) { index in
                    OnboardingPageView(page: featurePages[index])
                        .tag(index)
                }
                // Name capture page
                NameCapturePage(nameInput: $nameInput, isFocused: $nameFocused)
                    .tag(featurePages.count)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .animation(.easeInOut, value: currentPage)
            // Dismiss keyboard when swiping away from name page
            .onChange(of: currentPage) {
                if !isNamePage { nameFocused = false }
            }

            // — Bottom button area —
            VStack(spacing: 0) {
                if !isLastPage {
                    Button {
                        withAnimation { currentPage += 1 }
                    } label: {
                        Text("Next")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    Button("Skip") {
                        withAnimation { currentPage = totalPages - 1 }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

                } else {
                    // Last page (name capture) — save name then go to Home
                    Button {
                        saveNameAndFinish()
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
            .padding(.bottom, 48)
        }
    }

    // MARK: - Helpers

    private func saveNameAndFinish() {
        let trimmed = nameInput.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            // Rename the default "Me" profile to the user's chosen name
            Task { @MainActor in
                if let profile = ProfileService.shared.activeProfile {
                    ProfileService.shared.rename(profile, to: trimmed)
                }
            }
        }
        hasCompletedOnboarding = true
    }
}

// MARK: - Name Capture Page

private struct NameCapturePage: View {
    @Binding var nameInput: String
    @FocusState.Binding var isFocused: Bool

    var body: some View {
        VStack(spacing: 32) {

            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 160, height: 160)
                Image(systemName: "person.fill")
                    .font(.system(size: 72, weight: .semibold))
                    .foregroundStyle(.purple)
            }

            // Text
            VStack(spacing: 12) {
                Text("What's your name?")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                Text("We'll use it to personalise your greeting every day.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Name field
            TextField("Enter your name", text: $nameInput)
                .font(.title3)
                .multilineTextAlignment(.center)
                .focused($isFocused)
                .submitLabel(.done)
                .padding(.vertical, 14)
                .padding(.horizontal, 20)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 40)

            Spacer()
            Spacer()
        }
        .onTapGesture { isFocused = true }
    }
}

#Preview {
    OnboardingView()
}
