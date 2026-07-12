//
//  ProfileService.swift
//  DayPlanner (PlanDay)
//
//  Single source of truth for user profiles.
//
//  Profiles list is stored in UserDefaults (small, keyed data).
//  The active profile ID is also in UserDefaults.
//  Plan history per-profile lives in a separate JSON file in Documents,
//  named "history_<profileID>.json" — so switching profiles automatically
//  shows that profile's plans, and data never leaks between profiles.
//
//  ProfileService is @Observable so any View that reads activeProfile
//  re-renders automatically when the user switches.
//

import Foundation
import Observation

@MainActor
@Observable
final class ProfileService {

    static let shared = ProfileService()

    // MARK: - State

    /// All stored profiles (max 5)
    private(set) var profiles: [UserProfile] = []

    /// The currently active profile
    private(set) var activeProfile: UserProfile?

    // MARK: - Constants

    static let maxProfiles = 5
    private let profilesKey  = "user_profiles_v1"
    private let activeIDKey  = "active_profile_id_v1"

    // MARK: - Init

    private init() {
        load()
        // If no profiles exist yet, create a default "Me" profile automatically
        if profiles.isEmpty {
            let defaultProfile = UserProfile(name: "Me")
            profiles = [defaultProfile]
            activeProfile = defaultProfile
            persist()
        }
    }

    // MARK: - Public API

    /// Creates a new profile and activates it. Returns false if at max capacity.
    @discardableResult
    func createProfile(name: String, avatarSymbol: String = "person.fill", avatarColor: String = "#3B82F6") -> Bool {
        guard profiles.count < ProfileService.maxProfiles else { return false }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        let profile = UserProfile(name: trimmed, avatarSymbol: avatarSymbol, avatarColor: avatarColor)
        profiles.append(profile)
        activeProfile = profile
        persist()
        return true
    }

    /// Switches to an existing profile.
    func switchTo(_ profile: UserProfile) {
        guard profiles.contains(where: { $0.id == profile.id }) else { return }
        activeProfile = profile
        UserDefaults.standard.set(profile.id.uuidString, forKey: activeIDKey)
        // TripHistoryService reads activeProfile lazily, so no further call needed.
    }

    /// Renames a profile.
    func rename(_ profile: UserProfile, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[index].name = trimmed
        if activeProfile?.id == profile.id {
            activeProfile = profiles[index]
        }
        persist()
    }

    /// Deletes a profile and its history file. Cannot delete the last profile.
    func delete(_ profile: UserProfile) {
        guard profiles.count > 1 else { return }
        // Remove history file
        let historyURL = historyFileURL(for: profile.id)
        try? FileManager.default.removeItem(at: historyURL)
        // Remove from list
        profiles.removeAll { $0.id == profile.id }
        // If we deleted the active one, switch to first remaining
        if activeProfile?.id == profile.id {
            activeProfile = profiles.first
            UserDefaults.standard.set(activeProfile?.id.uuidString, forKey: activeIDKey)
        }
        persist()
    }

    /// Returns the history file URL for the currently active profile.
    /// Called by TripHistoryService to isolate data per profile.
    func activeHistoryFileURL() -> URL {
        let id = activeProfile?.id ?? UUID()
        return historyFileURL(for: id)
    }

    // MARK: - Private helpers

    private func historyFileURL(for profileID: UUID) -> URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("history_\(profileID.uuidString).json")
    }

    private func load() {
        // Load profiles list
        if let data = UserDefaults.standard.data(forKey: profilesKey),
           let decoded = try? JSONDecoder().decode([UserProfile].self, from: data) {
            profiles = decoded
        }
        // Load active profile ID
        if let idString = UserDefaults.standard.string(forKey: activeIDKey),
           let id = UUID(uuidString: idString),
           let match = profiles.first(where: { $0.id == id }) {
            activeProfile = match
        } else {
            activeProfile = profiles.first
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        UserDefaults.standard.set(data, forKey: profilesKey)
        UserDefaults.standard.set(activeProfile?.id.uuidString, forKey: activeIDKey)
    }
}
