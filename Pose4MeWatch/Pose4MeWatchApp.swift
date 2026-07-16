import SwiftUI
import WatchConnectivity
import WidgetKit

/// Receives the phone's countdown + stats via application context and stores them
/// in the watch-side app group so the app UI and complications share one source.
final class PhoneSyncReceiver: NSObject, WCSessionDelegate, ObservableObject {
    static let appGroupID = "group.pose-for-me.shared"

    @Published var nextFireDate: Date?
    @Published var streakDays = 0
    @Published var todayCount = 0

    override init() {
        super.init()
        load()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    private func load() {
        let defaults = UserDefaults(suiteName: Self.appGroupID)
        nextFireDate = defaults?.object(forKey: "widget.nextFireDate") as? Date
        streakDays = defaults?.integer(forKey: "widget.streakDays") ?? 0
        todayCount = defaults?.integer(forKey: "widget.todayCount") ?? 0
    }

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {}

    nonisolated func session(_ session: WCSession,
                             didReceiveApplicationContext applicationContext: [String: Any]) {
        let defaults = UserDefaults(suiteName: Self.appGroupID)
        defaults?.set(applicationContext["nextFireDate"] as? Date, forKey: "widget.nextFireDate")
        defaults?.set(applicationContext["streakDays"] as? Int ?? 0, forKey: "widget.streakDays")
        defaults?.set(applicationContext["todayCount"] as? Int ?? 0, forKey: "widget.todayCount")
        WidgetCenter.shared.reloadAllTimelines()
        Task { @MainActor [weak self] in self?.load() }
    }
}

struct WatchHomeView: View {
    @EnvironmentObject private var sync: PhoneSyncReceiver

    private let mint = Color(red: 0x4e / 255, green: 0xe6 / 255, blue: 0xc1 / 255)
    private let ember = Color(red: 0xf5 / 255, green: 0x9e / 255, blue: 0x0b / 255)

    var body: some View {
        VStack(spacing: 8) {
            if let next = sync.nextFireDate, next > .now {
                Text(timerInterval: Date.now...next, countsDown: true)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(mint)
                    .multilineTextAlignment(.center)
                Text("until next stretch")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if sync.nextFireDate != nil {
                Image(systemName: "figure.flexibility")
                    .font(.largeTitle)
                    .foregroundStyle(mint)
                Text("Time to stretch!")
                    .font(.headline)
            } else {
                Image(systemName: "iphone.and.arrow.forward")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Open Pose4Me on your iPhone to sync")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                Label("\(sync.streakDays)", systemImage: "flame.fill")
                    .foregroundStyle(ember)
                Label("\(sync.todayCount)", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(mint)
            }
            .font(.footnote.bold())
            .padding(.top, 4)
        }
        .padding()
    }
}

@main
struct Pose4MeWatchApp: App {
    @StateObject private var sync = PhoneSyncReceiver()

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
                .environmentObject(sync)
        }
    }
}
