//
//  SettingsView.swift
//  DayPlanner
//
//  The Settings screen — lets the user personalise the app.
//  Three settings:
//    1. Your Name         — shown in the "Good morning, NAME!" greeting
//    2. Default Transport — pre-selects driving/walking/transit in TripBuilder
//    3. Appearance        — light / dark / system (follows iPhone setting)
//
//  Why @AppStorage instead of a ViewModel?
//  All three settings are simple key-value pairs that belong in UserDefaults.
//  @AppStorage is SwiftUI's direct wrapper around UserDefaults — it reads and
//  writes automatically, and any view that reads the same key re-renders when
//  it changes. No ViewModel, no service, no JSON file needed.
//
//  Why .preferredColorScheme on ContentView instead of here?
//  .preferredColorScheme must sit at the top of the view hierarchy to affect
//  the whole app. We store the raw string in @AppStorage and read it in
//  ContentView (the root) to apply it there.
//

import SwiftUI

struct SettingsView: View {

    @AppStorage("defaultTravelMode")       private var defaultTravelMode = TravelMode.driving.rawValue
    @AppStorage("appearanceMode")          private var appearanceMode = "system"
    // Whether the user wants reminder notifications for their plans.
    @AppStorage("notificationsEnabled")    private var notificationsEnabled = true

    @State private var profileService = ProfileService.shared
    @State private var showingProfiles = false
    @State private var notificationPermissionGranted = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {

                // MARK: Profile section
                Section {
                    Button { showingProfiles = true } label: {
                        HStack(spacing: 14) {
                            // Avatar
                            let color = Color.hex( profileService.activeProfile?.accentColor.hexValue ?? "#3B82F6")
                            ZStack {
                                Circle()
                                    .fill(color.opacity(0.2))
                                    .frame(width: 48, height: 48)
                                Text(profileService.activeProfile?.initials ?? "?")
                                    .font(.title3.bold())
                                    .foregroundStyle(color)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(profileService.activeProfile?.name ?? "Me")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("\(profileService.profiles.count) profile\(profileService.profiles.count == 1 ? "" : "s") · Tap to manage")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Profile")
                }
                .sheet(isPresented: $showingProfiles) {
                    ProfileSwitcherView()
                }

                // MARK: Trip Defaults section
                Section {
                    Picker("Default transport", selection: $defaultTravelMode) {
                        ForEach(TravelMode.allCases, id: \.rawValue) { mode in
                            Label(mode.rawValue, systemImage: mode.symbolName)
                                .tag(mode.rawValue)
                        }
                    }
                    // .segmented shows the three modes as a compact control
                    .pickerStyle(.segmented)
                    .padding(.vertical, 4)
                } header: {
                    Text("Trip Defaults")
                } footer: {
                    Text("Pre-selected when you start planning a new trip.")
                }

                // MARK: Notifications section
                Section {
                    Toggle(isOn: $notificationsEnabled) {
                        Label("Plan Reminders", systemImage: "bell.fill")
                    }
                    if !notificationPermissionGranted {
                        Button("Enable in Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.blue)
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Get reminders the evening before and morning of each plan.")
                }
                .task {
                    notificationPermissionGranted = await NotificationService.shared.isPermissionGranted()
                }

                // MARK: Appearance section
                Section {
                    Picker("Appearance", selection: $appearanceMode) {
                        Label("System", systemImage: "iphone").tag("system")
                        Label("Light",  systemImage: "sun.max").tag("light")
                        Label("Dark",   systemImage: "moon").tag("dark")
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("\"System\" follows your iPhone's display settings.")
                }

                // MARK: About section
                Section {
                    LabeledContent("Version", value: appVersion)
                    LabeledContent("Built with", value: "SwiftUI + MapKit")
                } header: {
                    Text("About")
                }

                // MARK: Danger zone
                Section {
                    Button(role: .destructive) {
                        resetOnboarding()
                    } label: {
                        Label("Reset Onboarding", systemImage: "arrow.counterclockwise")
                    }
                } footer: {
                    Text("Shows the welcome screens again on next launch.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .bold()
                }
            }
        }
    }

    // MARK: - Helpers

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    private func resetOnboarding() {
        hasCompletedOnboarding = false
        dismiss()
    }
}

#Preview {
    SettingsView()
}
