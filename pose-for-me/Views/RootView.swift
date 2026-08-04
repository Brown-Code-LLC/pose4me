import Combine
import SwiftUI

/// Main app shell: tab navigation + session/tip-jar presentation.
struct RootView: View {
    @EnvironmentObject private var settings: UserSettings
    @EnvironmentObject private var scheduler: ReminderScheduler
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var cloudBackup: CloudBackup
    @ObservedObject private var launcher = SessionLauncher.shared

    @State private var tab: Tab = .home
    @State private var activeExercise: Exercise?
    @State private var activeRoutine: Routine?
    @State private var showTipJar = false

    enum Tab { case home, library, stats, settings }

    var body: some View {
        TabView(selection: $tab) {
            screen { HomeView(activeExercise: $activeExercise, activeRoutine: $activeRoutine) }
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
        .fullScreenCover(item: $activeRoutine) { routine in
            RoutineSessionView(routine: routine)
        }
        .sheet(isPresented: $showTipJar) {
            TipJarView()
        }
        .onChange(of: scheduler.pendingSessionRequest) { _, pending in
            // Notification tap -> straight into a stretch.
            guard pending else { return }
            scheduler.pendingSessionRequest = false
            activeExercise = settings.suggestedExercise(history: sessionStore.records)
        }
        .onChange(of: activeExercise == nil && activeRoutine == nil) { _, dismissed in
            // Non-destructive: completing a stretch resets the countdown from
            // SessionView's Done button; merely closing the sheet must not.
            if dismissed {
                Task { await scheduler.refresh(settings: settings.data) }
                // Freshly recorded sessions ride up to iCloud right away.
                cloudBackup.sync(store: sessionStore)
            }
        }
        .onChange(of: launcher.stretchRequested) { _, requested in
            // Siri / Shortcuts / Action button -> straight into a stretch.
            guard requested else { return }
            launcher.stretchRequested = false
            activeExercise = settings.suggestedExercise(history: sessionStore.records)
        }
        .onChange(of: scheduler.pendingRecapRequest) { _, pending in
            // Sunday recap tap -> the Progress tab, where the share card lives.
            guard pending else { return }
            scheduler.pendingRecapRequest = false
            tab = .stats
        }
        .onOpenURL { url in
            // Widget/complication tap -> straight into a stretch.
            if url.scheme == "pose4me" {
                activeExercise = settings.suggestedExercise(history: sessionStore.records)
            }
        }
        .task {
            WatchSyncService.shared.activate()
            sessionStore.publishToWidgets()
            cloudBackup.sync(store: sessionStore)
            // Cold start from an intent: the flag may be set before onChange exists.
            if launcher.stretchRequested {
                launcher.stretchRequested = false
                activeExercise = settings.suggestedExercise(history: sessionStore.records)
            }
            await scheduler.refresh(settings: settings.data)
            #if DEBUG
            // UI-testing hooks: `-pose4me.autostart <id>` opens a session on launch,
            // `-pose4me.tab <home|library|stats|settings>` selects a tab,
            // `-pose4me.showTipJar YES` presents the tip jar (IAP screenshots).
            if UserDefaults.standard.bool(forKey: "pose4me.showTipJar") {
                showTipJar = true
            }
            switch UserDefaults.standard.string(forKey: "pose4me.tab") {
            case "library": tab = .library
            case "stats": tab = .stats
            case "settings": tab = .settings
            default: break
            }
            if let id = UserDefaults.standard.string(forKey: "pose4me.autostart") {
                activeExercise = Exercise.byID(id) ?? settings.suggestedExercise(history: sessionStore.records)
            }
            // `-pose4me.routine <id>` opens a routine on launch.
            if let id = UserDefaults.standard.string(forKey: "pose4me.routine") {
                activeRoutine = Routine.byID(id)
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
