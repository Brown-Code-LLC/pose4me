import Foundation

/// Reads the state the app publishes through the shared app-group container.
/// Mirror of WidgetBridge in the app target — keep keys in sync.
struct SharedState {
    static let appGroupID = "group.pose-for-me.shared"

    var nextFireDate: Date?
    var streakDays: Int
    var todayCount: Int

    static func load() -> SharedState {
        let defaults = UserDefaults(suiteName: appGroupID)
        return SharedState(
            nextFireDate: defaults?.object(forKey: "widget.nextFireDate") as? Date,
            streakDays: defaults?.integer(forKey: "widget.streakDays") ?? 0,
            todayCount: defaults?.integer(forKey: "widget.todayCount") ?? 0
        )
    }
}
