import Foundation
import WidgetKit

/// Publishes the app's live state to the widget/watch surfaces through the shared
/// app-group container, and pokes WidgetKit to re-render.
///
/// Keys are read by Pose4MeWidget (iOS) and mirrored to the watch via
/// WatchSyncService — keep them in sync with SharedState.swift in the widget target.
enum WidgetBridge {
    static let appGroupID = "group.com.browncode.pose4me"

    private static var defaults: UserDefaults? { UserDefaults(suiteName: appGroupID) }

    static func setNextFireDate(_ date: Date?) {
        defaults?.set(date, forKey: "widget.nextFireDate")
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func setStats(streakDays: Int, todayCount: Int) {
        defaults?.set(streakDays, forKey: "widget.streakDays")
        defaults?.set(todayCount, forKey: "widget.todayCount")
        WidgetCenter.shared.reloadAllTimelines()
    }
}
