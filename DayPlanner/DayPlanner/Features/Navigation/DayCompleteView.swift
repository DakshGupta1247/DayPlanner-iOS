//
//  DayCompleteView.swift
//  DayPlanner
//
//  Shown when all stops in a day plan have been marked arrived.
//  Displays trip summary stats, completed stop list, and confetti.
//

import SwiftUI

struct DayCompleteView: View {

    let summary: DaySummary
    let completedStops: [Stop]
    let onDone: () -> Void

    var body: some View {
        ZStack {
            // Background
            Color(.systemGroupedBackground).ignoresSafeArea()

            // Confetti layer
            ConfettiView()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            ScrollView {
                VStack(spacing: 28) {

                    // MARK: - Header
                    VStack(spacing: 12) {
                        Text("🎉")
                            .font(.system(size: 80))
                            .padding(.top, 48)

                        Text("Day Complete!")
                            .font(.largeTitle.bold())

                        Text("You visited all \(summary.totalStops) stop\(summary.totalStops == 1 ? "" : "s")")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }

                    // MARK: - Stats card
                    VStack(spacing: 0) {
                        StatRow(icon: "mappin.circle.fill",
                                iconColor: .blue,
                                label: "Stops Completed",
                                value: "\(summary.completedStops) of \(summary.totalStops)",
                                badge: "✅")

                        Divider().padding(.horizontal, 16)

                        StatRow(icon: "timer",
                                iconColor: .orange,
                                label: "Time Taken",
                                value: summary.timeTaken,
                                badge: nil)

                        Divider().padding(.horizontal, 16)

                        StatRow(icon: "flag.fill",
                                iconColor: .green,
                                label: "Started",
                                value: summary.startTime.formatted(date: .omitted, time: .shortened),
                                badge: nil)

                        Divider().padding(.horizontal, 16)

                        StatRow(icon: "checkmark.seal.fill",
                                iconColor: .purple,
                                label: "Completed",
                                value: summary.endTime.formatted(date: .omitted, time: .shortened),
                                badge: nil)
                    }
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
                    .padding(.horizontal, 20)

                    // MARK: - Completed stops list
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Visited Stops")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)

                        VStack(spacing: 0) {
                            ForEach(Array(completedStops.enumerated()), id: \.element.id) { index, stop in
                                HStack(spacing: 12) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .font(.title3)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(stop.name)
                                            .font(.subheadline.bold())
                                        Text(stop.address)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()

                                    Text("\(stop.minutesToSpend) min")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)

                                if index < completedStops.count - 1 {
                                    Divider().padding(.horizontal, 16)
                                }
                            }
                        }
                        .background(.background)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
                    }
                    .padding(.horizontal, 20)

                    // MARK: - Buttons
                    VStack(spacing: 12) {
                        Button(action: onDone) {
                            Text("Back to Home")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(.blue)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 48)
                }
            }
        }
    }
}

// MARK: - Stat Row

private struct StatRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    let badge: String?

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .font(.title3)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.bold())
            }

            Spacer()

            if let badge {
                Text(badge)
                    .font(.title3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Confetti

private struct ConfettiView: View {

    @State private var animate = false

    private let pieces: [(x: CGFloat, delay: Double, color: Color, rotation: Double)] = (0..<25).map { _ in
        (
            x: CGFloat.random(in: 0.05...0.95),
            delay: Double.random(in: 0...1.2),
            color: [Color.blue, .green, .orange, .pink, .purple, .yellow].randomElement()!,
            rotation: Double.random(in: 0...360)
        )
    }

    var body: some View {
        GeometryReader { geo in
            ForEach(0..<pieces.count, id: \.self) { i in
                let p = pieces[i]
                RoundedRectangle(cornerRadius: 2)
                    .fill(p.color)
                    .frame(width: 8, height: 14)
                    .rotationEffect(.degrees(animate ? p.rotation + 360 : p.rotation))
                    .position(
                        x: geo.size.width * p.x,
                        y: animate ? geo.size.height + 20 : -20
                    )
                    .opacity(animate ? 0 : 1)
                    .animation(
                        .easeIn(duration: 1.8)
                        .delay(p.delay),
                        value: animate
                    )
            }
        }
        .onAppear { animate = true }
    }
}

#Preview {
    DayCompleteView(
        summary: DaySummary(
            totalStops: 4,
            completedStops: 4,
            startTime: Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: .now)!,
            endTime: Calendar.current.date(bySettingHour: 13, minute: 25, second: 0, of: .now)!
        ),
        completedStops: [
            Stop(name: "Connaught Place", address: "New Delhi", latitude: 28.6315, longitude: 77.2167),
            Stop(name: "India Gate", address: "Rajpath, New Delhi", latitude: 28.6129, longitude: 77.2295),
            Stop(name: "Humayun's Tomb", address: "Nizamuddin East", latitude: 28.5933, longitude: 77.2507),
            Stop(name: "Qutub Minar", address: "Mehrauli", latitude: 28.5244, longitude: 77.1855)
        ],
        onDone: {}
    )
}
