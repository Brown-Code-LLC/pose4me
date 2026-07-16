import Foundation
import WatchConnectivity

/// Mirrors the countdown + stats to the paired Apple Watch via application context
/// (latest-value semantics — exactly what a complication needs). The watch app
/// stores the payload and its complications render from it.
@MainActor
final class WatchSyncService: NSObject {
    static let shared = WatchSyncService()

    nonisolated deinit {}

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Call at launch so the session activates even before the first change.
    func activate() {}

    /// Pushes the current shared state; safe to call often (context replaces itself).
    func push() {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated,
              WCSession.default.isPaired, WCSession.default.isWatchAppInstalled else { return }
        let defaults = UserDefaults(suiteName: WidgetBridge.appGroupID)
        var context: [String: Any] = [
            "streakDays": defaults?.integer(forKey: "widget.streakDays") ?? 0,
            "todayCount": defaults?.integer(forKey: "widget.todayCount") ?? 0,
        ]
        if let next = defaults?.object(forKey: "widget.nextFireDate") as? Date {
            context["nextFireDate"] = next
        }
        try? WCSession.default.updateApplicationContext(context)
    }
}

extension WatchSyncService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        Task { @MainActor in self.push() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
