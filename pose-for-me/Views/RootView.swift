import Combine
import SwiftUI

/// Main app shell: tab navigation + session/paywall presentation.
struct RootView: View {
    @EnvironmentObject private var settings: UserSettings
    @EnvironmentObject private var scheduler: ReminderScheduler
    @EnvironmentObject private var entitlements: Entitlements

    @State private var tab: Tab = .home
    @State private var activeExercise: Exercise?
    @State private var showPaywall = false

    enum Tab { case home, library, stats, settings }

    var body: some View {
        TabView(selection: $tab) {
            screen { HomeView(activeExercise: $activeExercise) }
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
                .tag(Tab.home)
            screen { LibraryView(activeExercise: $activeExercise, showPaywall: $showPaywall) }
                .tabItem { Label("Library", systemImage: "square.grid.2x2.fill") }
                .tag(Tab.library)
            screen { StatsView(showPaywall: $showPaywall) }
                .tabItem { Label("Progress", systemImage: "chart.bar.fill") }
                .tag(Tab.stats)
            screen { SettingsView(showPaywall: $showPaywall) }
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(Tab.settings)
        }
        .tint(Theme.aurora1)
        .preferredColorScheme(.dark)
        .fullScreenCover(item: $activeExercise) { exercise in
            SessionView(exercise: exercise, settings: settings.data)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .onChange(of: scheduler.pendingSessionRequest) { _, pending in
            // Notification tap -> straight into a stretch.
            guard pending else { return }
            scheduler.pendingSessionRequest = false
            activeExercise = settings.suggestedExercise(isPro: entitlements.isPro)
        }
        .onChange(of: activeExercise == nil) { _, dismissed in
            // After each session, refresh the reminder chain so the countdown restarts.
            if dismissed {
                Task { await scheduler.reschedule(settings: settings.data) }
            }
        }
        .task {
            await scheduler.reschedule(settings: settings.data)
            #if DEBUG
            // UI-testing hook: `simctl launch <udid> <bundle> -pose4me.autostart <id>`
            // jumps straight into a session (or any exercise id) on launch.
            if let id = UserDefaults.standard.string(forKey: "pose4me.autostart") {
                activeExercise = Exercise.byID(id) ?? settings.suggestedExercise(isPro: true)
            }
            #endif
        }
    }

    /// Each tab paints the shared aurora background (TabView children are opaque).
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
