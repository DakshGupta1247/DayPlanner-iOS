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
    @State private var logoScale: CGFloat = 0.8
    @State private var contentOpacity: Double = 0.0
    @State private var taglineOpacity: Double = 0.0

    @AppStorage("hasSeenWelcomeScreen") private var hasSeenWelcomeScreen = false
    @State private var profileService = ProfileService.shared

    // Reads the appearance preference saved by SettingsView.
    // Applied here because SplashScreenView is the true root of the view hierarchy.
    @AppStorage("appearanceMode") private var appearanceMode = "system"

    @Environment(\.colorScheme) private var colorScheme

    // Background: dark navy in dark mode, off-white in light mode.
    private var splashBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.04, green: 0.09, blue: 0.16)  // #0A1628
            : Color(red: 0.96, green: 0.97, blue: 0.99)  // near-white
    }

    // Title: white in dark mode, near-black in light mode.
    private var titleColor: Color {
        colorScheme == .dark ? .white : Color(red: 0.1, green: 0.1, blue: 0.15)
    }

    // Tagline: muted white in dark mode, muted gray in light mode.
    private var taglineColor: Color {
        colorScheme == .dark ? .white.opacity(0.5) : Color.secondary
    }

    var body: some View {
        Group {
        if isActive {
            if !hasSeenWelcomeScreen {
                // First-time user: show welcome screen (it routes to profile creation).
                WelcomeScreenView()
                    .transition(.opacity)
            } else if profileService.profiles.count <= 1 && profileService.profiles.first?.name == "Me" {
                // Only the auto-created "Me" default profile — go to creation
                ProfileCreationView()
                    .transition(.opacity)
            } else {
                // Returning user with real profiles — show profile picker
                ProfileSelectionView()
                    .transition(.opacity)
            }
        } else {
            // The actual splash content.
            splashContent
        }
        }
        .preferredColorScheme(resolvedColorScheme)
    }

    private var resolvedColorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    // MARK: - Splash Content

    private var splashContent: some View {
        ZStack {
            splashBackground.ignoresSafeArea()

            VStack(spacing: 20) {

                // App logo — loaded from the AppLogo image set in Assets.xcassets.
                // (AppIcon.appiconset is for the OS icon only; AppLogo.imageset
                //  is the named image we can load at runtime with Image("AppLogo").)
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 26))
                    .shadow(color: Color(red: 0.15, green: 0.39, blue: 0.92).opacity(0.6),
                            radius: 24, x: 0, y: 8)
                    .scaleEffect(logoScale)

                Text("PlanDay")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(titleColor)

                // Tagline + subtitle — fade in after logo (delay 0.8s)
                VStack(spacing: 6) {
                    Text("Your Journey Starts Here ✈️")
                        .font(.subheadline.bold())
                        .foregroundStyle(titleColor)
                    Text("Plan smarter. Travel better. Live fully.")
                        .font(.caption)
                        .foregroundStyle(Color(red: 0.56, green: 0.56, blue: 0.58)) // #8E8E93
                }
                .opacity(taglineOpacity)
            }
            .opacity(contentOpacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                logoScale = 1.0
                contentOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.8)) {
                taglineOpacity = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
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
