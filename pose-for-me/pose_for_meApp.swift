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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(sessionStore)
                .environmentObject(scheduler)
                .environmentObject(entitlements)
        }
        .onChange(of: scenePhase) { _, phase in
            // Keep the pending-notification chain topped up whenever we background.
            if phase == .background, settings.data.hasOnboarded {
                Task { await scheduler.reschedule(settings: settings.data) }
            }
        }
    }
}
