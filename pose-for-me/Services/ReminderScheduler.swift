import Combine
import Foundation
import UserNotifications

/// Schedules the "time to stretch" local notifications from the user's settings:
/// interval, active hours, and active weekdays. Notifications carry Start/Snooze
/// actions; tapping Start deep-links straight into a camera session.
@MainActor
final class ReminderScheduler: NSObject, ObservableObject {
    static let categoryID = "POSE4ME_STRETCH"
    static let startActionID = "START_STRETCH"
    static let snoozeActionID = "SNOOZE_STRETCH"

    @Published private(set) var authorizationGranted = false
    @Published private(set) var nextFireDate: Date?

    /// Set when the user opens the app from a stretch notification; RootView observes
    /// this and launches a session.
    @Published var pendingSessionRequest = false

    /// Cached from the last reschedule so the notification snooze action can honor it.
    private var snoozeMinutes = 10

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        registerCategory()
    }

    func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        authorizationGranted = granted
    }

    private func registerCategory() {
        let start = UNNotificationAction(identifier: Self.startActionID,
                                         title: "Start stretch",
                                         options: [.foreground])
        let snooze = UNNotificationAction(identifier: Self.snoozeActionID,
                                          title: "Snooze")
        let category = UNNotificationCategory(identifier: Self.categoryID,
                                              actions: [start, snooze],
                                              intentIdentifiers: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    /// Recomputes and schedules the next batch of reminders (iOS caps pending
    /// notifications at 64; 24 upcoming slots is days of coverage at any interval).
    func reschedule(settings: SettingsData) async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        nextFireDate = nil
        snoozeMinutes = settings.snoozeMinutes
        guard settings.remindersEnabled, authorizationGranted else { return }

        let slots = upcomingSlots(settings: settings, count: 24)
        for (index, date) in slots.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = Self.titles[index % Self.titles.count]
            content.body = Self.bodies[index % Self.bodies.count]
            content.sound = .default
            content.categoryIdentifier = Self.categoryID
            content.interruptionLevel = .timeSensitive

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: "pose4me.reminder.\(index)",
                                                content: content, trigger: trigger)
            try? await center.add(request)
        }
        nextFireDate = slots.first
    }

    func snooze(minutes: Int) async {
        let content = UNMutableNotificationContent()
        content.title = "Snooze is over 😌"
        content.body = "A quick stretch now beats a stiff back later."
        content.sound = .default
        content.categoryIdentifier = Self.categoryID
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(minutes * 60), repeats: false)
        let request = UNNotificationRequest(identifier: "pose4me.snooze",
                                            content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Next `count` reminder times respecting interval, active hours and weekdays.
    func upcomingSlots(settings: SettingsData, count: Int) -> [Date] {
        let calendar = Calendar.current
        let interval = TimeInterval(settings.reminderIntervalMinutes * 60)
        var slots: [Date] = []
        var cursor = Date().addingTimeInterval(interval)

        // Walk forward in interval steps, skipping inactive hours/days.
        var safety = 0
        while slots.count < count && safety < 2000 {
            safety += 1
            let hour = calendar.component(.hour, from: cursor)
            let weekday = calendar.component(.weekday, from: cursor)
            let isActiveDay = settings.activeWeekdays.contains(weekday)
            let isActiveHour = hour >= settings.activeStartHour && hour < settings.activeEndHour

            if isActiveDay && isActiveHour {
                slots.append(cursor)
                cursor = cursor.addingTimeInterval(interval)
            } else {
                // Jump to the next active window start.
                var next = calendar.date(bySettingHour: settings.activeStartHour,
                                         minute: 0, second: 0, of: cursor) ?? cursor
                if next <= cursor {
                    next = calendar.date(byAdding: .day, value: 1, to: next) ?? cursor
                }
                cursor = next.addingTimeInterval(interval)
            }
        }
        return slots
    }

    private static let titles = [
        "Time to stretch 🧘",
        "Your body called — it wants a minute",
        "Circulation break!",
        "Stand up, superstar ⭐️",
        "60 seconds for future-you",
    ]
    private static let bodies = [
        "One minute of movement now keeps you sharp for the next hour.",
        "Open the app and copy the pose — the camera does the counting.",
        "Long sitting slows your blood flow. Let's fix that in 60 seconds.",
        "A quick reach and a bend — your spine will thank you.",
        "Your streak is watching 👀",
    ]
}

extension ReminderScheduler: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let action = response.actionIdentifier
        await MainActor.run {
            switch action {
            case Self.snoozeActionID:
                break // handled below, needs settings-free default
            default:
                // Default tap or explicit "Start stretch" both open a session.
                self.pendingSessionRequest = true
            }
        }
        if action == Self.snoozeActionID {
            let minutes = await MainActor.run { self.snoozeMinutes }
            await snooze(minutes: minutes)
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
