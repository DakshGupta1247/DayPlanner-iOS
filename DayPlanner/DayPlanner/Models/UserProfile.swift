//
//  UserProfile.swift
//  DayPlanner (PlanDay)
//
//  A user profile — name, SF Symbol avatar, accent color.
//  Each profile has its own history file so plan data is fully isolated.
//  Max 5 profiles are enforced by ProfileService.
//

import Foundation

struct UserProfile: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var avatarSymbol: String   // SF Symbol name, e.g. "person.fill"
    var avatarColor: String    // Hex string, e.g. "#3B82F6"

    var initials: String {
        let words = name.split(separator: " ")
        let letters = words.prefix(2).compactMap { $0.first }
        return String(letters).uppercased().isEmpty ? "?" : String(letters).uppercased()
    }

    // Legacy support — accentColor derived from avatarColor
    var accentColor: ProfileColor {
        ProfileColor.allCases.first { $0.hexValue == avatarColor }
            ?? ProfileColor.allCases[abs(id.hashValue) % ProfileColor.allCases.count]
    }

    init(id: UUID = UUID(), name: String, avatarSymbol: String = "person.fill", avatarColor: String = "#3B82F6") {
        self.id = id
        self.name = name
        self.avatarSymbol = avatarSymbol
        self.avatarColor = avatarColor
    }
}

// MARK: - ProfileColor

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

// MARK: - Avatar options

enum ProfileAvatar: CaseIterable {
    case person, star, heart, bolt, leaf, flame, moon, airplane

    var symbolName: String {
        switch self {
        case .person:   return "person.fill"
        case .star:     return "star.fill"
        case .heart:    return "heart.fill"
        case .bolt:     return "bolt.fill"
        case .leaf:     return "leaf.fill"
        case .flame:    return "flame.fill"
        case .moon:     return "moon.fill"
        case .airplane: return "airplane"
        }
    }
}
