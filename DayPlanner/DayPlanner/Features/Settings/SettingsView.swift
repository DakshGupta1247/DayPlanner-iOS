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

    // These keys must match exactly what HomeView and ContentView read.
    @AppStorage("userName")           private var userName = "there"
    @AppStorage("defaultTravelMode")  private var defaultTravelMode = TravelMode.driving.rawValue
    @AppStorage("appearanceMode")     private var appearanceMode = "system"

    // Local state for the name text field
    @State private var nameInput = ""
    @FocusState private var nameFocused: Bool

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {

                // MARK: Profile section
                Section {
                    HStack {
                        // Big avatar circle with initials
                        ZStack {
                            Circle()
                                .fill(.blue.opacity(0.15))
                                .frame(width: 56, height: 56)
                            Text(initials)
                                .font(.title2.bold())
                                .foregroundStyle(.blue)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(userName == "there" ? "Set your name" : userName)
                                .font(.headline)
                            Text("Used in your daily greeting")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    // Inline text field to change name
                    HStack {
                        TextField("Your name", text: $nameInput)
                            .focused($nameFocused)
                            .submitLabel(.done)
                            .onSubmit { saveName() }

                        if !nameInput.isEmpty {
                            Button("Save") { saveName() }
                                .font(.subheadline.bold())
                                .foregroundStyle(.blue)
                        }
                    }
                } header: {
                    Text("Profile")
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
            // Pre-fill the text field with the current saved name
            .onAppear {
                nameInput = userName == "there" ? "" : userName
            }
        }
    }

    // MARK: - Helpers

    /// Saves the typed name to @AppStorage (UserDefaults).
    private func saveName() {
        let trimmed = nameInput.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            userName = trimmed
        }
        nameFocused = false
    }

    /// Up-to-2-letter initials from the saved name, e.g. "Daksh Gupta" → "DG"
    private var initials: String {
        guard userName != "there" else { return "?" }
        let words = userName.split(separator: " ")
        let letters = words.prefix(2).compactMap { $0.first }
        return String(letters).uppercased()
    }

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
