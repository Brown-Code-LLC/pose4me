//
//  pose_for_meApp.swift
//  pose-for-me
//
//  Pose4Me — stretch reminders with camera pose tracking.
//

import Combine
import SwiftUI

@main
struct pose_for_meApp: App {
    @StateObject private var settings = UserSettings()
    @StateObject private var sessionStore = SessionStore()
    @StateObject private var scheduler = ReminderScheduler()
    @StateObject private var entitlements = Entitlements()

    @Environment(\.scenePhase) private var scenePhase

    init() {
        AppFonts.registerAll()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(settings.colorSchemeOverride)
                .environmentObject(settings)
                .environmentObject(sessionStore)
                .environmentObject(scheduler)
                .environmentObject(entitlements)
        }
        .onChange(of: scenePhase) { _, phase in
            // Non-destructive sync: tops up an exhausted chain but never resets a
            // running countdown just because the app was backgrounded.
            if phase == .background, settings.data.hasOnboarded {
                Task { await scheduler.refresh(settings: settings.data) }
            }
        }
    }
}
