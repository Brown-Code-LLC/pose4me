import Combine
import Foundation
import SwiftUI

/// Every user-tunable knob in the app, persisted as one Codable blob.
/// Adding a setting = add a property here + a control in SettingsView.
struct SettingsData: Codable, Equatable {
    // Reminders
    var reminderIntervalMinutes: Int = 60        // 30...240
    // Active window boundaries. Any combination works: daytime (9:00-18:00),
    // overnight (22:30-6:15), or equal start/end for around-the-clock.
    var activeStartHour: Int = 9
    var activeStartMinute: Int = 0
    var activeEndHour: Int = 18
    var activeEndMinute: Int = 0
    var activeWeekdays: Set<Int> = [2, 3, 4, 5, 6] // Calendar weekday numbers (1 = Sunday)
    var snoozeMinutes: Int = 10
    var remindersEnabled: Bool = true

    // Sessions
    var sessionSeconds: Int = 60                 // 30 / 60 / 90 / custom
    var previewSeconds: Int = 15                 // movement demo before start; 0 = off
    var cameraTrackingEnabled: Bool = true
    var matchStrictness: Double = 0.5            // 0 relaxed ... 1 strict
    var seatedFriendlyOnly: Bool = false
    var maxDifficulty: Int = Difficulty.energizing.rawValue
    var enabledCategories: Set<String> = Set(ExerciseCategory.allCases.map(\.rawValue))

    // Feel
    var hapticsEnabled: Bool = true
    var voiceCuesEnabled: Bool = false
    var appearance: String = "system"            // system / light / dark

    // Lifecycle
    var hasOnboarded: Bool = false

    /// Window boundaries as minutes from midnight, the unit the scheduler compares in.
    var activeStartMinutesFromMidnight: Int { activeStartHour * 60 + activeStartMinute }
    var activeEndMinutesFromMidnight: Int { activeEndHour * 60 + activeEndMinute }

    init() {}

    /// Lenient decoding: any key missing from an older stored blob falls back to its
    /// default, so adding a setting never wipes existing users' preferences.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = SettingsData()
        reminderIntervalMinutes = try c.decodeIfPresent(Int.self, forKey: .reminderIntervalMinutes) ?? d.reminderIntervalMinutes
        activeStartHour = try c.decodeIfPresent(Int.self, forKey: .activeStartHour) ?? d.activeStartHour
        activeStartMinute = try c.decodeIfPresent(Int.self, forKey: .activeStartMinute) ?? d.activeStartMinute
        activeEndHour = try c.decodeIfPresent(Int.self, forKey: .activeEndHour) ?? d.activeEndHour
        activeEndMinute = try c.decodeIfPresent(Int.self, forKey: .activeEndMinute) ?? d.activeEndMinute
        activeWeekdays = try c.decodeIfPresent(Set<Int>.self, forKey: .activeWeekdays) ?? d.activeWeekdays
        snoozeMinutes = try c.decodeIfPresent(Int.self, forKey: .snoozeMinutes) ?? d.snoozeMinutes
        remindersEnabled = try c.decodeIfPresent(Bool.self, forKey: .remindersEnabled) ?? d.remindersEnabled
        sessionSeconds = try c.decodeIfPresent(Int.self, forKey: .sessionSeconds) ?? d.sessionSeconds
        previewSeconds = try c.decodeIfPresent(Int.self, forKey: .previewSeconds) ?? d.previewSeconds
        cameraTrackingEnabled = try c.decodeIfPresent(Bool.self, forKey: .cameraTrackingEnabled) ?? d.cameraTrackingEnabled
        matchStrictness = try c.decodeIfPresent(Double.self, forKey: .matchStrictness) ?? d.matchStrictness
        seatedFriendlyOnly = try c.decodeIfPresent(Bool.self, forKey: .seatedFriendlyOnly) ?? d.seatedFriendlyOnly
        maxDifficulty = try c.decodeIfPresent(Int.self, forKey: .maxDifficulty) ?? d.maxDifficulty
        enabledCategories = try c.decodeIfPresent(Set<String>.self, forKey: .enabledCategories) ?? d.enabledCategories
        hapticsEnabled = try c.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? d.hapticsEnabled
        voiceCuesEnabled = try c.decodeIfPresent(Bool.self, forKey: .voiceCuesEnabled) ?? d.voiceCuesEnabled
        appearance = try c.decodeIfPresent(String.self, forKey: .appearance) ?? d.appearance
        hasOnboarded = try c.decodeIfPresent(Bool.self, forKey: .hasOnboarded) ?? d.hasOnboarded
    }
}

@MainActor
final class UserSettings: ObservableObject {
    // Xcode 26.2's Swift runtime intermittently aborts in the isolated-deinit
    // executor hop (malloc abort in TaskLocal scope) when MainActor classes
    // deallocate. Deinit only releases storage, which is thread-safe, so opt
    // out of isolation and skip the crashing hop entirely.
    nonisolated deinit {}

    @Published var data: SettingsData {
        didSet {
            guard data != oldValue else { return }
            save()
            Haptics.isEnabled = data.hapticsEnabled
        }
    }

    private static let storageKey = "pose4me.settings.v1"

    init() {
        if let raw = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(SettingsData.self, from: raw) {
            data = decoded
        } else {
            data = SettingsData()
        }

        #if DEBUG
        // UI-testing hooks (launch arguments land in the UserDefaults argument
        // domain; none of these mutations persist because didSet skips init).
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "pose4me.resetSettings") { data = SettingsData() }
        if defaults.bool(forKey: "pose4me.skipOnboarding") { data.hasOnboarded = true }
        let overrideSession = defaults.integer(forKey: "pose4me.sessionSeconds")
        if (10...300).contains(overrideSession) { data.sessionSeconds = overrideSession }
        if defaults.object(forKey: "pose4me.previewSeconds") != nil {
            data.previewSeconds = defaults.integer(forKey: "pose4me.previewSeconds")
        }
        #endif

        Haptics.isEnabled = data.hapticsEnabled
    }

    private func save() {
        if let raw = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(raw, forKey: Self.storageKey)
        }
    }

    /// Exercises that pass the user's filters (category, difficulty, seated, entitlement).
    func eligibleExercises(isPro: Bool) -> [Exercise] {
        Exercise.library.filter { ex in
            (!ex.isPro || isPro)
                && ex.difficulty.rawValue <= data.maxDifficulty
                && enabledCategoriesSet.contains(ex.category)
                && (!data.seatedFriendlyOnly || ex.seatedFriendly)
        }
    }

    var enabledCategoriesSet: Set<ExerciseCategory> {
        Set(data.enabledCategories.compactMap(ExerciseCategory.init(rawValue:)))
    }

    /// nil = follow the system; otherwise force light/dark.
    var colorSchemeOverride: ColorScheme? {
        switch data.appearance {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }

    /// Deterministic-but-rotating pick so the suggested stretch changes each hour.
    func suggestedExercise(isPro: Bool) -> Exercise {
        let pool = eligibleExercises(isPro: isPro)
        guard !pool.isEmpty else { return Exercise.library[0] }
        let hourStamp = Int(Date().timeIntervalSince1970 / 3600)
        return pool[hourStamp % pool.count]
    }
}
