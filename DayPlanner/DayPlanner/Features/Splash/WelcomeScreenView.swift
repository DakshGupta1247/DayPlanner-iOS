//
//  WelcomeScreenView.swift
//  DayPlanner (PlanDay)
//
//  Shown only on the FIRST launch, right after the Splash Screen.
//  Purpose: give new users a warm, polished introduction to the app
//  before dropping them into HomeView.
//
//  HOW IT WORKS:
//  1. Each UI element (logo, heading, subtitle, button) fades in one at a time
//     using a staggered @State opacity animation triggered on .onAppear.
//  2. Tapping "Get Started" writes true to UserDefaults key "hasSeenWelcomeScreen",
//     so SplashScreenView will skip this screen on all future launches.
//  3. The transition to HomeView uses a slide-up (.move(edge: .bottom)) + fade.
//

import SwiftUI

struct WelcomeScreenView: View {

    // When true, we cross-fade/slide to HomeView.
    @State private var navigateToHome = false

    // Staggered opacity states — each element fades in separately.
    @State private var logoOpacity:    Double = 0
    @State private var headingOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0
    @State private var buttonOpacity:  Double = 0

    // Writes true when the user taps "Get Started" — prevents this screen
    // from ever showing again after the first time.
    @AppStorage("hasSeenWelcomeScreen") private var hasSeenWelcomeScreen = false

    private let royalBlue = Color(red: 0.15, green: 0.39, blue: 0.92) // #2563EB

    @Environment(\.colorScheme) private var colorScheme

    private var welcomeBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.04, green: 0.09, blue: 0.16)
            : Color(red: 0.96, green: 0.97, blue: 0.99)
    }

    private var headingColor: Color {
        colorScheme == .dark ? .white : Color(red: 0.1, green: 0.1, blue: 0.15)
    }

    private var subtitleColor: Color {
        colorScheme == .dark ? .white.opacity(0.6) : Color.secondary
    }

    var body: some View {
        if navigateToHome {
            // Hand off to profile creation with a slide-up transition.
            ProfileCreationView()
                .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            welcomeContent
        }
    }

    // MARK: - Welcome Content

    private var welcomeContent: some View {
        ZStack {
            welcomeBackground.ignoresSafeArea()

            VStack(spacing: 0) {

                Spacer()

                // ── App Logo ──────────────────────────────────────────────
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 26))
                    .shadow(color: royalBlue.opacity(0.5), radius: 20, x: 0, y: 8)
                    .opacity(logoOpacity)
                    .padding(.bottom, 40)

                // ── Heading ───────────────────────────────────────────────
                Text("Plan Your\nPerfect Day")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(headingColor)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .opacity(headingOpacity)
                    .padding(.bottom, 16)

                // ── Subtitle ──────────────────────────────────────────────
                Text("Organize trips, plan routes,\nand make every day count.")
                    .font(.body)
                    .foregroundStyle(subtitleColor)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .opacity(subtitleOpacity)

                Spacer()

                // ── CTA Button ────────────────────────────────────────────
                Button {
                    // Mark welcome as seen so it never shows again.
                    hasSeenWelcomeScreen = true
                    // Animate transition to HomeView.
                    withAnimation(.easeInOut(duration: 0.45)) {
                        navigateToHome = true
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text("Get Started")
                            .font(.headline)
                        Image(systemName: "arrow.right")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(royalBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    // Subtle glow under the button
                    .shadow(color: royalBlue.opacity(0.45), radius: 12, x: 0, y: 6)
                }
                .opacity(buttonOpacity)
                .padding(.horizontal, 28)
                .padding(.bottom, 52)
            }
        }
        .onAppear {
            // Stagger each element's fade-in with a small delay between them.
            // This feels more polished than everything appearing at once.
            withAnimation(.easeOut(duration: 0.5).delay(0.1))  { logoOpacity    = 1 }
            withAnimation(.easeOut(duration: 0.5).delay(0.35)) { headingOpacity  = 1 }
            withAnimation(.easeOut(duration: 0.5).delay(0.55)) { subtitleOpacity = 1 }
            withAnimation(.easeOut(duration: 0.5).delay(0.75)) { buttonOpacity   = 1 }
        }
    }
}

#Preview {
    WelcomeScreenView()
}
