import XCTest
@testable import pose_for_me

final class SettingsAndModelTests: XCTestCase {

    // MARK: SettingsData migration

    func testDecodingEmptyBlobFallsBackToAllDefaults() throws {
        let decoded = try JSONDecoder().decode(SettingsData.self, from: Data("{}".utf8))
        XCTAssertEqual(decoded, SettingsData(),
                       "missing keys must fall back to defaults, not fail decoding")
    }

    func testDecodingOldBlobKeepsUserValuesAndDefaultsNewFields() throws {
        // A blob from before previewSeconds/appearance/minute fields existed.
        let old = #"{"reminderIntervalMinutes":90,"activeStartHour":8,"activeEndHour":20,"hasOnboarded":true}"#
        let decoded = try JSONDecoder().decode(SettingsData.self, from: Data(old.utf8))
        XCTAssertEqual(decoded.reminderIntervalMinutes, 90)
        XCTAssertEqual(decoded.activeStartHour, 8)
        XCTAssertTrue(decoded.hasOnboarded)
        XCTAssertEqual(decoded.previewSeconds, SettingsData().previewSeconds)
        XCTAssertEqual(decoded.appearance, "system")
        XCTAssertEqual(decoded.activeStartMinute, 0)
    }

    func testRoundTripPreservesEverything() throws {
        var s = SettingsData()
        s.reminderIntervalMinutes = 45
        s.activeStartHour = 22; s.activeStartMinute = 30
        s.activeEndHour = 5; s.activeEndMinute = 45
        s.activeWeekdays = [1, 7]
        s.previewSeconds = 30
        s.appearance = "dark"
        s.matchStrictness = 0.9
        let data = try JSONEncoder().encode(s)
        let back = try JSONDecoder().decode(SettingsData.self, from: data)
        XCTAssertEqual(back, s)
    }

    func testMinutesFromMidnightComputation() {
        var s = SettingsData()
        s.activeStartHour = 22; s.activeStartMinute = 30
        s.activeEndHour = 5; s.activeEndMinute = 45
        XCTAssertEqual(s.activeStartMinutesFromMidnight, 1350)
        XCTAssertEqual(s.activeEndMinutesFromMidnight, 345)
    }

    // MARK: Exercise library integrity

    func testLibraryHasUniqueIDsAndValidKeyframes() {
        var seen = Set<String>()
        for exercise in Exercise.library {
            XCTAssertTrue(seen.insert(exercise.id).inserted, "duplicate id \(exercise.id)")
            XCTAssertFalse(exercise.keyframes.isEmpty, "\(exercise.name) has no keyframes")
            XCTAssertGreaterThan(exercise.totalSeconds, 0)
            for kf in exercise.keyframes {
                XCTAssertGreaterThan(kf.holdSeconds, 0)
                XCTAssertFalse(kf.cue.isEmpty)
            }
        }
    }

    func testLibraryIsFullyFree() {
        // The whole library ships free; keep it substantial.
        XCTAssertGreaterThanOrEqual(Exercise.library.count, 19)
    }

    func testFittedScalesToRequestedDuration() {
        let exercise = Exercise.byID("overhead-reach")!
        let fitted = exercise.fitted(to: 60)
        let total = fitted.reduce(0) { $0 + $1.holdSeconds }
        XCTAssertEqual(total, 60, accuracy: 1.0)
        XCTAssertEqual(fitted.count, exercise.keyframes.count)
    }

    func testFittedNeverProducesUnusablyShortHolds() {
        for exercise in Exercise.library {
            for kf in exercise.fitted(to: 30) {
                XCTAssertGreaterThanOrEqual(kf.holdSeconds, 3,
                    "\(exercise.name): a hold under 3s is not a stretch")
            }
        }
    }

    @MainActor
    func testEligibleExercisesRespectsFilters() {
        let settings = UserSettings()
        settings.data = SettingsData()
        settings.data.seatedFriendlyOnly = true
        settings.data.maxDifficulty = Difficulty.gentle.rawValue
        let pool = settings.eligibleExercises()
        for ex in pool {
            XCTAssertTrue(ex.seatedFriendly)
            XCTAssertEqual(ex.difficulty, .gentle)
        }
        XCTAssertFalse(pool.isEmpty, "gentle seated stretches must exist")
    }

    @MainActor
    func testSuggestedExerciseAlwaysReturnsSomething() {
        let settings = UserSettings()
        settings.data.enabledCategories = [] // pathological config
        _ = settings.suggestedExercise() // must not crash
    }

    // MARK: Streaks

    @MainActor
    func testStreakCountsConsecutiveDays() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        func record(daysAgo: Int) -> SessionRecord {
            SessionRecord(exerciseID: "overhead-reach",
                          date: cal.date(byAdding: .day, value: -daysAgo, to: today)!
                                .addingTimeInterval(3600 * 10),
                          durationSeconds: 60, averageMatchScore: 0.8)
        }
        let store = SessionStore(testRecords: [record(daysAgo: 0), record(daysAgo: 1), record(daysAgo: 2)])
        XCTAssertEqual(store.streakDays, 3)
    }

    @MainActor
    func testStreakSurvivesUntilEndOfToday() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        // Stretched yesterday but not yet today: streak should still show 1, not 0.
        let record = SessionRecord(exerciseID: "overhead-reach",
                                   date: cal.date(byAdding: .day, value: -1, to: today)!
                                        .addingTimeInterval(3600 * 12),
                                   durationSeconds: 60, averageMatchScore: nil)
        let store = SessionStore(testRecords: [record])
        XCTAssertEqual(store.streakDays, 1)
    }

    @MainActor
    func testGapBreaksStreak() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let record = SessionRecord(exerciseID: "overhead-reach",
                                   date: cal.date(byAdding: .day, value: -3, to: today)!,
                                   durationSeconds: 60, averageMatchScore: nil)
        let store = SessionStore(testRecords: [record])
        XCTAssertEqual(store.streakDays, 0)
    }

    @MainActor
    func testDailyCountsShapeAndTotals() {
        let store = SessionStore(testRecords: [
            SessionRecord(exerciseID: "overhead-reach", date: Date(),
                          durationSeconds: 60, averageMatchScore: nil),
            SessionRecord(exerciseID: "neck-side-stretch", date: Date(),
                          durationSeconds: 30, averageMatchScore: nil),
        ])
        let days = store.dailyCounts(days: 14)
        XCTAssertEqual(days.count, 14)
        XCTAssertEqual(days.last?.count, 2)
        XCTAssertEqual(days.last?.minutes ?? 0, 1.5, accuracy: 0.01)
        XCTAssertEqual(store.todayCount, 2)
    }
}
