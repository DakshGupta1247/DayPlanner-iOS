//
//  SplashScreenView.swift
//  DayPlanner (PlanDay)
//
//  The very first screen the user sees on every launch.
//  Shows the app logo + name on a dark navy background for ~2 seconds,
//  then automatically advances to either:
//    - WelcomeScreenView (if this is the user's first launch ever)
//    - HomeView           (on all subsequent launches)
//
//  HOW THE FLOW WORKS:
//  SplashScreenView owns a @State var that tracks which screen to show next.
//  After a 2-second delay it flips that state, SwiftUI re-renders, and we
//  cross-fade to the next screen. No navigation stack needed.
//

import SwiftUI

struct SplashScreenView: View {

    // Tracks whether the 2-second timer has fired and we should move on.
    @State private var isActive = false

    // Whether we're in the scale-up animation phase (logo grows 0.8 → 1.0).
    @State private var logoScale: CGFloat = 0.8

    // Controls the fade-in of the logo + title after they scale up.
    @State private var contentOpacity: Double = 0.0

    // Reads the UserDefaults key written by WelcomeScreenView.
    // false = user has never seen the welcome screen → show it after splash.
    // true  = user already saw it → go straight to HomeView.
    @AppStorage("hasSeenWelcomeScreen") private var hasSeenWelcomeScreen = false

    // Dark navy — the brand background colour used across splash and welcome.
    private let navyBackground = Color(red: 0.04, green: 0.09, blue: 0.16) // #0A1628

    var body: some View {
        if isActive {
            // Timer fired — hand off to the correct next screen.
            if hasSeenWelcomeScreen {
                // Returning user: skip welcome, go straight home.
                HomeView()
                    .transition(.opacity)
            } else {
                // First-time user: show welcome screen.
                WelcomeScreenView()
                    .transition(.opacity)
            }
        } else {
            // The actual splash content.
            splashContent
        }
    }

    // MARK: - Splash Content

    private var splashContent: some View {
        ZStack {
            // Full-screen dark navy background
            navyBackground.ignoresSafeArea()

            VStack(spacing: 20) {

                // App logo — loaded from the AppLogo image set in Assets.xcassets.
                // (AppIcon.appiconset is for the OS icon only; AppLogo.imageset
                //  is the named image we can load at runtime with Image("AppLogo").)
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 26))
                    // Glowing shadow to make the logo pop on the dark bg.
                    .shadow(color: Color(red: 0.15, green: 0.39, blue: 0.92).opacity(0.6),
                            radius: 24, x: 0, y: 8)
                    // Scale animation: 0.8 → 1.0 on appear.
                    .scaleEffect(logoScale)

                // App name in large bold white
                Text("PlanDay")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                // Tagline in smaller muted text
                Text("Plan smart. Travel better.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .opacity(contentOpacity)
        }
        .onAppear {
            // Step 1: Animate logo scale + fade-in over 0.6s (easeOut feels snappy).
            withAnimation(.easeOut(duration: 0.6)) {
                logoScale = 1.0
                contentOpacity = 1.0
            }

            // Step 2: After 2 seconds, cross-fade to the next screen.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    isActive = true
                }
            }
        }
    }
}

#Preview {
    SplashScreenView()
}
