import Combine
import Foundation
import SwiftUI

/// Every user-tunable knob in the app, persisted as one Codable blob.
/// Adding a setting = add a property here + a control in SettingsView.
struct SettingsData: Codable, Equatable {
    // Reminders
    var reminderIntervalMinutes: Int = 60        // 30...240
    var activeStartHour: Int = 9
    var activeEndHour: Int = 18
    var activeWeekdays: Set<Int> = [2, 3, 4, 5, 6] // Calendar weekday numbers (1 = Sunday)
    var snoozeMinutes: Int = 10
    var remindersEnabled: Bool = true

    // Sessions
    var sessionSeconds: Int = 60                 // 30 / 60 / 90 / custom
    var cameraTrackingEnabled: Bool = true
    var matchStrictness: Double = 0.5            // 0 relaxed ... 1 strict
    var seatedFriendlyOnly: Bool = false
    var maxDifficulty: Int = Difficulty.energizing.rawValue
    var enabledCategories: Set<String> = Set(ExerciseCategory.allCases.map(\.rawValue))

    // Feel
    var hapticsEnabled: Bool = true
    var voiceCuesEnabled: Bool = false

    // Lifecycle
    var hasOnboarded: Bool = false
}

@MainActor
final class UserSettings: ObservableObject {
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

    /// Deterministic-but-rotating pick so the suggested stretch changes each hour.
    func suggestedExercise(isPro: Bool) -> Exercise {
        let pool = eligibleExercises(isPro: isPro)
        guard !pool.isEmpty else { return Exercise.library[0] }
        let hourStamp = Int(Date().timeIntervalSince1970 / 3600)
        return pool[hourStamp % pool.count]
    }
}
