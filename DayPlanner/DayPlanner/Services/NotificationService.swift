//
//  NotificationService.swift
//  DayPlanner (PlanDay)
//
//  Manages local notifications that remind the user about upcoming plans.
//
//  HOW IT WORKS:
//  - When a plan is saved, we schedule a notification for the evening BEFORE
//    the plan's date (e.g. "Tomorrow: SF Day Out starts at 9:00 AM").
//  - When a plan is deleted, we cancel its notification by ID.
//  - We request permission the first time we try to schedule — iOS shows the
//    system prompt asking "Allow notifications?".
//
//  WHY LOCAL NOTIFICATIONS (not push)?
//  Local notifications are scheduled entirely on the device — no server needed.
//  Perfect for reminders tied to a date the user already set in the app.
//
//  KEY FRAMEWORK: UserNotifications (UNUserNotificationCenter)
//

import Foundation
import UserNotifications

@MainActor
final class NotificationService {

    // Singleton — one shared instance used everywhere in the app.
    static let shared = NotificationService()
    private init() {}

    // The notification center is the iOS API for all local notifications.
    private let center = UNUserNotificationCenter.current()

    // MARK: - Permission

    /// Requests notification permission from the user.
    /// iOS only shows the system prompt once — after that it returns the cached answer.
    func requestPermission() async {
        do {
            // .alert = banner, .sound = sound, .badge = app badge number
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if !granted {
                print("Notification permission denied by user.")
            }
        } catch {
            print("Notification permission error: \(error)")
        }
    }

    /// Returns true if the user has granted notification permission.
    func isPermissionGranted() async -> Bool {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized
    }

    // MARK: - Schedule

    /// Schedules an evening reminder the day before a plan's date.
    /// Also schedules a morning reminder on the day itself.
    /// Safe to call repeatedly — replaces any existing notification for this plan ID.
    func scheduleReminder(for item: PlanItem) async {
        guard await isPermissionGranted() else { return }

        let planDate = item.startDate
        let planName = item.name
        let planID   = item.id.uuidString

        // Cancel any existing notification for this plan first (handles edits)
        center.removePendingNotificationRequests(withIdentifiers: [
            planID + "_evening",
            planID + "_morning"
        ])

        let today = Calendar.current.startOfDay(for: .now)
        let daysBefore = Calendar.current.dateComponents([.day],
            from: today,
            to: Calendar.current.startOfDay(for: planDate)).day ?? 0

        // Evening before — only schedule if the plan is at least 1 day away
        if daysBefore >= 1, let eveningTrigger = eveningBeforeTrigger(for: planDate) {
            let content = makeContent(
                title: "Tomorrow: \(planName)",
                body: "Your plan starts tomorrow. Tap to review your itinerary.",
                sound: true
            )
            let request = UNNotificationRequest(
                identifier: planID + "_evening",
                content: content,
                trigger: eveningTrigger
            )
            try? await center.add(request)
        }

        // Morning of — only if the plan is today or in the future
        if daysBefore >= 0, let morningTrigger = morningOfTrigger(for: planDate) {
            let content = makeContent(
                title: "Today: \(planName)",
                body: "Your plan starts today. Have a great day! 🗺️",
                sound: true
            )
            let request = UNNotificationRequest(
                identifier: planID + "_morning",
                content: content,
                trigger: morningTrigger
            )
            try? await center.add(request)
        }
    }

    // MARK: - Cancel

    /// Cancels all pending notifications for a plan (call when plan is deleted).
    func cancelReminder(for id: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [
            id.uuidString + "_evening",
            id.uuidString + "_morning"
        ])
    }

    // MARK: - Helpers

    /// Builds a UNMutableNotificationContent with title + body.
    private func makeContent(title: String, body: String, sound: Bool) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = sound ? .default : nil
        return content
    }

    /// Returns a calendar trigger for 7:00 PM the evening before the plan date.
    private func eveningBeforeTrigger(for date: Date) -> UNCalendarNotificationTrigger? {
        guard let dayBefore = Calendar.current.date(byAdding: .day, value: -1, to: date) else { return nil }
        var components = Calendar.current.dateComponents([.year, .month, .day], from: dayBefore)
        components.hour   = 19   // 7:00 PM
        components.minute = 0
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    }

    /// Returns a calendar trigger for 8:00 AM on the morning of the plan date.
    private func morningOfTrigger(for date: Date) -> UNCalendarNotificationTrigger? {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour   = 8    // 8:00 AM
        components.minute = 0
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    }
}
