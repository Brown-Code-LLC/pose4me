import AppIntents
import Combine
import Foundation

/// Cross-object channel for "start a stretch now" requests coming from App
/// Intents (Siri, Shortcuts, Spotlight, Action button). RootView observes it,
/// mirroring how notification taps arrive via ReminderScheduler.
@MainActor
final class SessionLauncher: ObservableObject {
    // Singleton never deallocates, but keep the project-wide MainActor-deinit
    // workaround for consistency (see SessionStore).
    nonisolated deinit {}

    static let shared = SessionLauncher()
    @Published var stretchRequested = false
}

/// Opens the app and starts the suggested stretch.
struct StartStretchIntent: AppIntent {
    static let title: LocalizedStringResource = "Start a Stretch"
    static let description = IntentDescription("Opens Pose4Me and starts the suggested stretch.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        SessionLauncher.shared.stretchRequested = true
        return .result()
    }
}

/// Registers the intent with Siri and Shortcuts under natural phrases.
struct Pose4MeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartStretchIntent(),
            phrases: [
                "Start a stretch in \(.applicationName)",
                "Start \(.applicationName)",
                "Stretch with \(.applicationName)",
                "Time to stretch with \(.applicationName)",
            ],
            shortTitle: "Start Stretch",
            systemImageName: "figure.flexibility"
        )
    }
}
