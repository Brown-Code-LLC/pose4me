import Combine
import SwiftUI

/// Main app shell: tab navigation + session/tip-jar presentation.
struct RootView: View {
    @EnvironmentObject private var settings: UserSettings
    @EnvironmentObject private var scheduler: ReminderScheduler
    @EnvironmentObject private var sessionStore: SessionStore

    @State private var tab: Tab = .home
    @State private var activeExercise: Exercise?
    @State private var showTipJar = false

    enum Tab { case home, library, stats, settings }

    var body: some View {
        TabView(selection: $tab) {
            screen { HomeView(activeExercise: $activeExercise) }
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
                .tag(Tab.home)
            screen { LibraryView(activeExercise: $activeExercise) }
                .tabItem { Label("Library", systemImage: "square.grid.2x2.fill") }
                .tag(Tab.library)
            screen { StatsView() }
                .tabItem { Label("Progress", systemImage: "chart.bar.fill") }
                .tag(Tab.stats)
            screen { SettingsView(showTipJar: $showTipJar) }
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(Tab.settings)
        }
        .tint(Theme.accent)
        .fullScreenCover(item: $activeExercise) { exercise in
            SessionView(exercise: exercise, settings: settings.data)
        }
        .sheet(isPresented: $showTipJar) {
            TipJarView()
        }
        .onChange(of: scheduler.pendingSessionRequest) { _, pending in
            // Notification tap -> straight into a stretch.
            guard pending else { return }
            scheduler.pendingSessionRequest = false
            activeExercise = settings.suggestedExercise()
        }
        .onChange(of: activeExercise == nil) { _, dismissed in
            // Non-destructive: completing a stretch resets the countdown from
            // SessionView's Done button; merely closing the sheet must not.
            if dismissed {
                Task { await scheduler.refresh(settings: settings.data) }
            }
        }
        .onOpenURL { url in
            // Widget/complication tap -> straight into a stretch.
            if url.scheme == "pose4me" {
                activeExercise = settings.suggestedExercise()
            }
        }
        .task {
            WatchSyncService.shared.activate()
            sessionStore.publishToWidgets()
            await scheduler.refresh(settings: settings.data)
            #if DEBUG
            // UI-testing hooks: `-pose4me.autostart <id>` opens a session on launch,
            // `-pose4me.tab <home|library|stats|settings>` selects a tab.
            switch UserDefaults.standard.string(forKey: "pose4me.tab") {
            case "library": tab = .library
            case "stats": tab = .stats
            case "settings": tab = .settings
            default: break
            }
            if let id = UserDefaults.standard.string(forKey: "pose4me.autostart") {
                activeExercise = Exercise.byID(id) ?? settings.suggestedExercise()
            }
            #endif
        }
    }

    /// Each tab paints the shared themed background (TabView children are opaque).
    private func screen<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ZStack {
            AppBackground()
            content()
        }
    }
}

extension Exercise: Equatable {
    static func == (lhs: Exercise, rhs: Exercise) -> Bool { lhs.id == rhs.id }
}
