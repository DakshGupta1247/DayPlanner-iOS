//
//  ProfileCreationView.swift
//  DayPlanner (PlanDay)
//
//  Shown only on the very first launch after the splash screen.
//  Asks for a name and avatar, then saves the profile and proceeds to HomeView.
//

import SwiftUI

struct ProfileCreationView: View {

    @State private var name = ""
    @State private var selectedSymbol = ProfileAvatar.person.symbolName
    @State private var selectedColor = "#3B82F6"
    @State private var navigateToHome = false

    @FocusState private var nameFieldFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    private let profileService = ProfileService.shared

    private let avatarColors = ["#3B82F6", "#6366F1", "#A855F7", "#EC4899", "#F97316", "#14B8A6", "#EF4444", "#10B981"]

    private var background: Color {
        colorScheme == .dark
            ? Color(red: 0.04, green: 0.09, blue: 0.16)
            : Color(red: 0.96, green: 0.97, blue: 0.99)
    }

    private var canProceed: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        if navigateToHome {
            HomeView()
                .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            content
        }
    }

    private var content: some View {
        ZStack {
            background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {

                    Spacer(minLength: 24)

                    // Avatar preview
                    ZStack {
                        Circle()
                            .fill(Color.hex(selectedColor).opacity(0.2))
                            .frame(width: 100, height: 100)
                        Image(systemName: selectedSymbol)
                            .font(.system(size: 44))
                            .foregroundStyle(Color.hex(selectedColor))
                    }
                    .animation(.spring(response: 0.3), value: selectedSymbol)
                    .animation(.spring(response: 0.3), value: selectedColor)

                    // Title
                    VStack(spacing: 6) {
                        Text("Create Your Profile")
                            .font(.title2.bold())
                        Text("Personalize your PlanDay experience")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Name field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Name")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                        TextField("e.g. Daksh", text: $name)
                            .font(.body)
                            .padding(14)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .focused($nameFieldFocused)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.words)
                    }
                    .padding(.horizontal, 28)

                    // Avatar symbol picker
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Choose Avatar")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 28)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(ProfileAvatar.allCases, id: \.symbolName) { avatar in
                                    Button {
                                        selectedSymbol = avatar.symbolName
                                    } label: {
                                        ZStack {
                                            Circle()
                                                .fill(selectedSymbol == avatar.symbolName
                                                      ? Color.hex(selectedColor).opacity(0.2)
                                                      : Color(.secondarySystemBackground))
                                                .frame(width: 56, height: 56)
                                                .overlay(
                                                    Circle()
                                                        .stroke(selectedSymbol == avatar.symbolName
                                                                ? Color.hex(selectedColor) : Color.clear,
                                                                lineWidth: 2)
                                                )
                                            Image(systemName: avatar.symbolName)
                                                .font(.title3)
                                                .foregroundStyle(selectedSymbol == avatar.symbolName
                                                                 ? Color.hex(selectedColor) : .secondary)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 28)
                        }
                    }

                    // Color picker
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Accent Color")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 28)
                        HStack(spacing: 12) {
                            ForEach(avatarColors, id: \.self) { hex in
                                Button {
                                    selectedColor = hex
                                } label: {
                                    Circle()
                                        .fill(Color.hex(hex))
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Circle()
                                                .stroke(.white, lineWidth: selectedColor == hex ? 3 : 0)
                                        )
                                        .shadow(color: Color.hex(hex).opacity(0.4), radius: 4)
                                        .scaleEffect(selectedColor == hex ? 1.15 : 1.0)
                                        .animation(.spring(response: 0.25), value: selectedColor)
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 28)
                    }

                    // Let's Go button
                    Button {
                        profileService.createProfile(
                            name: name.trimmingCharacters(in: .whitespaces),
                            avatarSymbol: selectedSymbol,
                            avatarColor: selectedColor
                        )
                        withAnimation(.easeInOut(duration: 0.4)) {
                            navigateToHome = true
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text("Let's Go")
                                .font(.headline)
                            Image(systemName: "arrow.right")
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(canProceed ? Color.hex(selectedColor) : Color.gray.opacity(0.35))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: canProceed ? Color.hex(selectedColor).opacity(0.4) : .clear, radius: 10, y: 4)
                    }
                    .disabled(!canProceed)
                    .padding(.horizontal, 28)
                    .animation(.easeInOut(duration: 0.2), value: canProceed)

                    Spacer(minLength: 32)
                }
            }
        }
        .onAppear { nameFieldFocused = true }
    }
}

#Preview {
    ProfileCreationView()
}
