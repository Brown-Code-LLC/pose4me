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
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var nextFireDate: Date? {
        didSet {
            guard nextFireDate != oldValue else { return }
            WidgetBridge.setNextFireDate(nextFireDate)
            WatchSyncService.shared.push()
        }
    }

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
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        await syncAuthorizationStatus()
    }

    /// Reads the real permission state from the system. Must run at every launch:
    /// the user may have granted/revoked permission in iOS Settings while we were
    /// closed, and a stale `authorizationGranted` misroutes the whole scheduler.
    func syncAuthorizationStatus() async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        authorizationStatus = status
        authorizationGranted = status == .authorized || status == .provisional || status == .ephemeral
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

    private static let fingerprintKey = "pose4me.schedule.fingerprint"
    private static let anchorKey = "pose4me.schedule.anchor"

    /// The reminder-relevant settings only — changing unrelated settings (haptics,
    /// session length...) must not reset the running countdown.
    private static func fingerprint(_ s: SettingsData) -> String {
        "\(s.remindersEnabled)|\(s.reminderIntervalMinutes)|\(s.activeStartMinutesFromMidnight)|\(s.activeEndMinutesFromMidnight)|\(s.activeWeekdays.sorted())"
    }

    /// Cheap, non-destructive sync — call on app open/foreground/background.
    ///
    /// The pending notification chain lives in the OS and keeps firing while the app
    /// is closed; this only re-reads the next fire time so the ring shows the truth.
    /// It rebuilds ONLY when the reminder settings changed or the chain is exhausted,
    /// so glancing at the app never resets the countdown.
    func refresh(settings: SettingsData) async {
        await syncAuthorizationStatus()
        snoozeMinutes = settings.snoozeMinutes
        guard settings.remindersEnabled else {
            nextFireDate = nil
            return
        }
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: Self.fingerprintKey) == Self.fingerprint(settings) else {
            await reschedule(settings: settings)
            return
        }

        if authorizationGranted {
            let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
            let next = pending
                .compactMap { ($0.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() }
                .filter { $0 > Date() }
                .min()
            if let next {
                nextFireDate = next
                return
            }
            // First run or every scheduled reminder already fired: rebuild the chain.
            await reschedule(settings: settings)
        } else {
            // No notification permission: keep the in-app countdown stable by rolling
            // the persisted anchor forward through the schedule instead of restarting.
            var anchor = defaults.object(forKey: Self.anchorKey) as? Date
                ?? upcomingSlots(settings: settings, count: 1).first
            while let current = anchor, current <= Date() {
                anchor = upcomingSlots(settings: settings, count: 1, from: current).first
            }
            nextFireDate = anchor
            if let anchor { defaults.set(anchor, forKey: Self.anchorKey) }
        }
    }

    /// Recomputes and schedules the next batch of reminders (iOS caps pending
    /// notifications at 64; 24 upcoming slots is days of coverage at any interval).
    /// Destructive: restarts the countdown from now. Call it for settings changes
    /// and completed stretches — use refresh() everywhere else.
    func reschedule(settings: SettingsData) async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        nextFireDate = nil
        snoozeMinutes = settings.snoozeMinutes
        guard settings.remindersEnabled else { return }

        let slots = upcomingSlots(settings: settings, count: 24)
        // The in-app countdown ring works even without notification permission.
        nextFireDate = slots.first
        UserDefaults.standard.set(Self.fingerprint(settings), forKey: Self.fingerprintKey)
        if let first = slots.first {
            UserDefaults.standard.set(first, forKey: Self.anchorKey)
        }
        guard authorizationGranted else { return }
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
        content.title = "Snooze is over"
        content.body = "A quick stretch now beats a stiff back later."
        content.sound = .default
        content.categoryIdentifier = Self.categoryID
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(minutes * 60), repeats: false)
        let request = UNNotificationRequest(identifier: "pose4me.snooze",
                                            content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Whether `date` falls inside the user's active window.
    ///
    /// Supports three window shapes so every schedule works:
    /// - daytime  (9 -> 18): the common case
    /// - overnight (22 -> 6): night shifts — the early-morning hours count as part
    ///   of the shift that *started the evening before*, so "active on Monday" means
    ///   Monday 22:00 through Tuesday 06:00
    /// - around the clock (start == end): always active on active days
    static func isActive(_ date: Date, settings: SettingsData,
                         calendar: Calendar = .current) -> Bool {
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        let minuteOfDay = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        let start = settings.activeStartMinutesFromMidnight
        let end = settings.activeEndMinutesFromMidnight

        let inWindow: Bool
        var shiftAnchor = date // the day whose weekday-toggle governs this moment
        if start == end {
            inWindow = true
        } else if start < end {
            inWindow = minuteOfDay >= start && minuteOfDay < end
        } else {
            inWindow = minuteOfDay >= start || minuteOfDay < end
            if minuteOfDay < end {
                shiftAnchor = calendar.date(byAdding: .day, value: -1, to: date) ?? date
            }
        }
        guard inWindow else { return false }
        return settings.activeWeekdays.contains(calendar.component(.weekday, from: shiftAnchor))
    }

    /// Next `count` reminder times after `date`, respecting interval, active hours
    /// and weekdays.
    func upcomingSlots(settings: SettingsData, count: Int, from date: Date = Date()) -> [Date] {
        let calendar = Calendar.current
        let interval = TimeInterval(settings.reminderIntervalMinutes * 60)
        var slots: [Date] = []
        var cursor = date.addingTimeInterval(interval)

        // Walk forward in interval steps, skipping inactive hours/days.
        var safety = 0
        while slots.count < count && safety < 2000 {
            safety += 1
            if Self.isActive(cursor, settings: settings, calendar: calendar) {
                slots.append(cursor)
                cursor = cursor.addingTimeInterval(interval)
            } else {
                // Jump to the next window start (today's if still ahead, else tomorrow's);
                // the first nudge lands one interval into the shift.
                var next = calendar.date(bySettingHour: settings.activeStartHour,
                                         minute: settings.activeStartMinute,
                                         second: 0, of: cursor) ?? cursor
                if next <= cursor {
                    next = calendar.date(byAdding: .day, value: 1, to: next) ?? cursor
                }
                cursor = next.addingTimeInterval(interval)
            }
        }
        return slots
    }

    private static let titles = [
        "Time to stretch",
        "A minute for your body",
        "Time to move",
        "Stretch break",
        "One minute, well spent",
    ]
    private static let bodies = [
        "One minute of movement keeps you sharp for the next hour.",
        "Open the app and follow the pose — the camera counts the hold for you.",
        "Sitting slows circulation. A sixty-second stretch restarts it.",
        "A slow reach and a deep breath. Your back will notice.",
        "Keep the streak alive — this one takes less than a minute.",
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
