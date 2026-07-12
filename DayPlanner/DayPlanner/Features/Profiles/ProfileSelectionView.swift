//
//  ProfileSelectionView.swift
//  DayPlanner (PlanDay)
//
//  Shown on every launch (after first time) so the user can pick which profile to use.
//  Netflix-style 2-column grid of profile avatar cells.
//  Tap to select → HomeView. "+ Add Profile" at end (max 5). "Manage" to rename/delete.
//

import SwiftUI

struct ProfileSelectionView: View {

    @State private var profileService = ProfileService.shared
    @State private var navigateToHome = false
    @State private var showingManage = false
    @State private var showingAddSheet = false

    @Environment(\.colorScheme) private var colorScheme

    private var background: Color {
        colorScheme == .dark
            ? Color(red: 0.04, green: 0.09, blue: 0.16)
            : Color(red: 0.96, green: 0.97, blue: 0.99)
    }

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        if navigateToHome {
            HomeView()
                .transition(.opacity)
        } else {
            content
        }
    }

    private var content: some View {
        ZStack {
            background.ignoresSafeArea()

            VStack(spacing: 0) {

                // Header
                VStack(spacing: 6) {
                    Text("Who's Planning Today?")
                        .font(.title2.bold())
                    Text("Select your profile to continue")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 52)
                .padding(.bottom, 32)

                // 2-column grid
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(profileService.profiles) { profile in
                            ProfileGridCell(profile: profile) {
                                profileService.switchTo(profile)
                                withAnimation(.easeInOut(duration: 0.35)) {
                                    navigateToHome = true
                                }
                            }
                        }

                        // Add profile cell
                        if profileService.profiles.count < ProfileService.maxProfiles {
                            AddProfileCell {
                                showingAddSheet = true
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }

                // Manage button
                Button {
                    showingManage = true
                } label: {
                    Text("Manage Profiles")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 24)
            }
        }
        .sheet(isPresented: $showingManage) {
            ProfileSwitcherView()
        }
        .sheet(isPresented: $showingAddSheet) {
            AddProfileSheet { name, symbol, color in
                profileService.createProfile(name: name, avatarSymbol: symbol, avatarColor: color)
            }
        }
    }
}

// MARK: - Profile Grid Cell

private struct ProfileGridCell: View {
    let profile: UserProfile
    let onTap: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.hex(profile.avatarColor).opacity(0.2))
                        .frame(width: 80, height: 80)
                    Image(systemName: profile.avatarSymbol)
                        .font(.system(size: 34))
                        .foregroundStyle(Color.hex(profile.avatarColor))
                }
                Text(profile.name)
                    .font(.subheadline.bold())
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
            .scaleEffect(pressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .pressEvents(onPress: { pressed = true }, onRelease: { pressed = false })
    }
}

// MARK: - Add Profile Cell

private struct AddProfileCell: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(.tertiarySystemBackground))
                        .frame(width: 80, height: 80)
                    Image(systemName: "plus")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Text("Add Profile")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(Color(.secondarySystemBackground).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.secondary.opacity(0.2), style: StrokeStyle(lineWidth: 1.5, dash: [6]))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Add Profile Sheet

struct AddProfileSheet: View {
    let onConfirm: (String, String, String) -> Void

    @State private var name = ""
    @State private var selectedSymbol = ProfileAvatar.person.symbolName
    @State private var selectedColor = "#3B82F6"
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    private let avatarColors = ["#3B82F6", "#6366F1", "#A855F7", "#EC4899", "#F97316", "#14B8A6", "#EF4444", "#10B981"]

    var body: some View {
        NavigationStack {
            Form {
                // Preview
                Section {
                    HStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(Color.hex(selectedColor).opacity(0.2))
                                .frame(width: 72, height: 72)
                            Image(systemName: selectedSymbol)
                                .font(.system(size: 30))
                                .foregroundStyle(Color.hex(selectedColor))
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                Section("Name") {
                    TextField("e.g. Priya", text: $name)
                        .focused($focused)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                }

                Section("Avatar") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(ProfileAvatar.allCases, id: \.symbolName) { avatar in
                                Button {
                                    selectedSymbol = avatar.symbolName
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(selectedSymbol == avatar.symbolName
                                                  ? Color.hex(selectedColor).opacity(0.15)
                                                  : Color(.tertiarySystemBackground))
                                            .frame(width: 48, height: 48)
                                            .overlay(Circle().stroke(
                                                selectedSymbol == avatar.symbolName
                                                    ? Color.hex(selectedColor) : Color.clear,
                                                lineWidth: 2))
                                        Image(systemName: avatar.symbolName)
                                            .foregroundStyle(selectedSymbol == avatar.symbolName
                                                             ? Color.hex(selectedColor) : .secondary)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Color") {
                    HStack(spacing: 12) {
                        ForEach(avatarColors, id: \.self) { hex in
                            Button { selectedColor = hex } label: {
                                Circle()
                                    .fill(Color.hex(hex))
                                    .frame(width: 28, height: 28)
                                    .overlay(Circle().stroke(.white, lineWidth: selectedColor == hex ? 3 : 0))
                                    .shadow(color: Color.hex(hex).opacity(0.4), radius: 3)
                                    .scaleEffect(selectedColor == hex ? 1.15 : 1.0)
                                    .animation(.spring(response: 0.25), value: selectedColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        onConfirm(trimmed, selectedSymbol, selectedColor)
                        dismiss()
                    }
                    .bold()
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .onAppear { focused = true }
    }
}

// MARK: - Press gesture helper

private extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onPress() }
                .onEnded { _ in onRelease() }
        )
    }
}

#Preview {
    ProfileSelectionView()
}
