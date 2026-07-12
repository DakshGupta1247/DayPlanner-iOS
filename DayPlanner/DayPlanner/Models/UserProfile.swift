//
//  UserProfile.swift
//  DayPlanner (PlanDay)
//
//  A user profile — just a name and a unique ID.
//  Each profile has its own history file so plan data is fully isolated.
//  Max 5 profiles are enforced by ProfileService.
//

import Foundation

struct UserProfile: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String       // e.g. "Daksh" or "Priya"

    // Up-to-2-letter initials used as the avatar, e.g. "Daksh Gupta" → "DG"
    var initials: String {
        let words = name.split(separator: " ")
        let letters = words.prefix(2).compactMap { $0.first }
        return String(letters).uppercased().isEmpty ? "?" : String(letters).uppercased()
    }

    // Accent color cycling through a palette so each profile looks distinct
    var accentColor: ProfileColor {
        ProfileColor.allCases[abs(id.hashValue) % ProfileColor.allCases.count]
    }

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

// MARK: - ProfileColor

/// A small palette of accent colours cycled per-profile.
enum ProfileColor: String, Codable, CaseIterable {
    case blue, indigo, purple, pink, orange, teal

    var hexValue: String {
        switch self {
        case .blue:   return "#3B82F6"
        case .indigo: return "#6366F1"
        case .purple: return "#A855F7"
        case .pink:   return "#EC4899"
        case .orange: return "#F97316"
        case .teal:   return "#14B8A6"
        }
    }
}
