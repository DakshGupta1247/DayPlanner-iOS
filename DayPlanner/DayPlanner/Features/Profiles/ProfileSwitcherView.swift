//
//  ProfileSwitcherView.swift
//  DayPlanner (PlanDay)
//
//  Shows all profiles in a list with the active one highlighted.
//  - Tap a row → switches to that profile
//  - "Add Profile" → text-field alert (blocked when at 5 profiles)
//  - Swipe-to-delete (blocked when only 1 profile remains)
//  - Long-press → rename alert
//
//  How switching works:
//  ProfileService.switchTo() updates activeProfile (Observable).
//  HomeViewModel.reload() is called via .onChange, which refetches from
//  the new profile's history file, so the home screen updates instantly.
//

import SwiftUI

struct ProfileSwitcherView: View {

    @State private var profileService = ProfileService.shared
    @Environment(\.dismiss) private var dismiss

    // New profile creation
    @State private var showingAddAlert  = false
    @State private var newProfileName   = ""

    // Rename
    @State private var profileToRename: UserProfile? = nil
    @State private var renameInput      = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(profileService.profiles) { profile in
                    ProfileRow(
                        profile: profile,
                        isActive: profileService.activeProfile?.id == profile.id
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        profileService.switchTo(profile)
                        dismiss()
                    }
                    // Long-press to rename
                    .contextMenu {
                        Button {
                            profileToRename = profile
                            renameInput = profile.name
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        if profileService.profiles.count > 1 {
                            Button(role: .destructive) {
                                profileService.delete(profile)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    // Swipe-to-delete (only if more than 1 profile)
                    .swipeActions(edge: .trailing) {
                        if profileService.profiles.count > 1 {
                            Button(role: .destructive) {
                                profileService.delete(profile)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }

                // Add Profile row — greyed out when at max
                if profileService.profiles.count < ProfileService.maxProfiles {
                    Button {
                        newProfileName = ""
                        showingAddAlert = true
                    } label: {
                        Label("Add Profile", systemImage: "plus.circle.fill")
                            .foregroundStyle(.blue)
                    }
                } else {
                    Label("Maximum 5 profiles reached", systemImage: "person.crop.circle.badge.exclamationmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Profiles")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .bold()
                }
            }
            // Add profile alert
            .alert("New Profile", isPresented: $showingAddAlert) {
                TextField("Name", text: $newProfileName)
                    .autocorrectionDisabled()
                Button("Create") {
                    profileService.createProfile(name: newProfileName)
                    dismiss()   // new profile is now active, go back home
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enter a name for the new profile.")
            }
            // Rename alert
            .alert("Rename Profile", isPresented: Binding(
                get: { profileToRename != nil },
                set: { if !$0 { profileToRename = nil } }
            )) {
                TextField("Name", text: $renameInput)
                    .autocorrectionDisabled()
                Button("Save") {
                    if let p = profileToRename {
                        profileService.rename(p, to: renameInput)
                    }
                    profileToRename = nil
                }
                Button("Cancel", role: .cancel) { profileToRename = nil }
            } message: {
                Text("Enter a new name for \"\(profileToRename?.name ?? "")\".")
            }
        }
    }
}

// MARK: - Profile Row

private struct ProfileRow: View {
    let profile: UserProfile
    let isActive: Bool

    private var color: Color { Color.hex( profile.accentColor.hexValue) }

    var body: some View {
        HStack(spacing: 14) {

            // Avatar circle with initials
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 44, height: 44)
                Text(profile.initials)
                    .font(.subheadline.bold())
                    .foregroundStyle(color)
            }

            // Name
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .font(.subheadline.bold())
                if isActive {
                    Text("Active")
                        .font(.caption2)
                        .foregroundStyle(color)
                }
            }

            Spacer()

            // Checkmark for active profile
            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(color)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ProfileSwitcherView()
}
