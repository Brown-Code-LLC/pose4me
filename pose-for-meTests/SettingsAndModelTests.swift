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

    @MainActor
    func testSuggestedExerciseSkipsRecentlyDone() {
        let settings = UserSettings()
        settings.data = SettingsData()
        let recent = ["overhead-reach", "neck-side-stretch", "cross-body-stretch"]
        let history = recent.map {
            SessionRecord(exerciseID: $0, date: Date(), durationSeconds: 60, averageMatchScore: nil)
        }
        let pick = settings.suggestedExercise(history: history)
        XCTAssertFalse(recent.contains(pick.id),
                       "the last three stretches must not be suggested again")
    }

    @MainActor
    func testSuggestedExerciseFavorsNeglectedCategory() {
        let settings = UserSettings()
        settings.data = SettingsData()
        // One session today in every category except Legs & Hips.
        let done = ["neck-side-stretch", "cross-body-stretch", "torso-twist",
                    "wrist-relief", "overhead-reach"]
        let history = done.map {
            SessionRecord(exerciseID: $0, date: Date(), durationSeconds: 60, averageMatchScore: nil)
        }
        let pick = settings.suggestedExercise(history: history)
        XCTAssertEqual(pick.category, .legs,
                       "the only never-stretched category should win")
    }

    // MARK: Routines

    @MainActor
    func testRoutineLibraryReferencesOnlyRealExercises() {
        for routine in Routine.library {
            XCTAssertGreaterThanOrEqual(routine.exerciseIDs.count, 2)
            XCTAssertEqual(Set(routine.exerciseIDs).count, routine.exerciseIDs.count,
                           "\(routine.name) repeats an exercise")
            for id in routine.exerciseIDs {
                XCTAssertNotNil(Exercise.byID(id),
                                "\(routine.name) references unknown exercise \(id)")
            }
        }
    }

    @MainActor
    func testEligibleExercisesInRoutineRespectsFilters() {
        let settings = UserSettings()
        settings.data = SettingsData()
        settings.data.seatedFriendlyOnly = true
        let deskBreak = Routine.byID("desk-break")!
        let pool = settings.eligibleExercises(in: deskBreak)
        XCTAssertFalse(pool.isEmpty, "the desk break must survive seated-only mode")
        for ex in pool { XCTAssertTrue(ex.seatedFriendly) }
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
    func testStreakShieldCoversSingleMissedDay() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let dayBeforeYesterday = cal.date(byAdding: .day, value: -2, to: today)!
        // 7 sessions earn one shield; yesterday is missed; the shield bridges it.
        var records = (0..<7).map { i in
            SessionRecord(exerciseID: "overhead-reach",
                          date: dayBeforeYesterday.addingTimeInterval(3600 + Double(i) * 600),
                          durationSeconds: 60, averageMatchScore: nil)
        }
        records.append(SessionRecord(exerciseID: "overhead-reach",
                                     date: today.addingTimeInterval(3600),
                                     durationSeconds: 60, averageMatchScore: nil))
        let store = SessionStore(testRecords: records)
        XCTAssertEqual(store.streakDays, 3, "today + covered day + session day")
        XCTAssertEqual(store.streakShields, 0, "the shield was spent on the gap")
    }

    @MainActor
    func testWithoutShieldsGapStillBreaksStreak() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let dayBeforeYesterday = cal.date(byAdding: .day, value: -2, to: today)!
        // Only 6 sessions: no shield earned, so the missed day breaks the streak.
        var records = (0..<5).map { i in
            SessionRecord(exerciseID: "overhead-reach",
                          date: dayBeforeYesterday.addingTimeInterval(3600 + Double(i) * 600),
                          durationSeconds: 60, averageMatchScore: nil)
        }
        records.append(SessionRecord(exerciseID: "overhead-reach",
                                     date: today.addingTimeInterval(3600),
                                     durationSeconds: 60, averageMatchScore: nil))
        let store = SessionStore(testRecords: records)
        XCTAssertEqual(store.streakDays, 1)
        XCTAssertEqual(store.streakShields, 0)
    }

    @MainActor
    func testShieldsNeverInventStreakDaysBeforeFirstSession() {
        // 7 sessions today earn a shield, but there is no earlier history for
        // it to bridge — the streak must stay at 1 and the shield stays held.
        let records = (0..<7).map { i in
            SessionRecord(exerciseID: "overhead-reach",
                          date: Calendar.current.startOfDay(for: Date())
                                .addingTimeInterval(3600 + Double(i) * 600),
                          durationSeconds: 60, averageMatchScore: nil)
        }
        let store = SessionStore(testRecords: records)
        XCTAssertEqual(store.streakDays, 1)
        XCTAssertEqual(store.streakShields, 1)
    }

    @MainActor
    func testCategoryAndExerciseTotals() {
        let store = SessionStore(testRecords: [
            SessionRecord(exerciseID: "overhead-reach", date: Date(),
                          durationSeconds: 60, averageMatchScore: 0.7),
            SessionRecord(exerciseID: "overhead-reach", date: Date(),
                          durationSeconds: 60, averageMatchScore: 0.9),
            SessionRecord(exerciseID: "neck-side-stretch", date: Date(),
                          durationSeconds: 30, averageMatchScore: nil),
        ])
        let categories = store.categoryTotals()
        XCTAssertEqual(categories.first?.category, .fullBody)
        XCTAssertEqual(categories.first?.count, 2)
        XCTAssertEqual(categories.first?.minutes ?? 0, 2.0, accuracy: 0.01)

        let exercises = store.exerciseTotals()
        XCTAssertEqual(exercises.first?.exercise.id, "overhead-reach")
        XCTAssertEqual(exercises.first?.count, 2)
        XCTAssertEqual(exercises.first?.bestForm ?? 0, 0.9, accuracy: 0.001)
        XCTAssertNil(exercises.last?.bestForm, "timer-only exercise has no form score")
    }

    // MARK: Cloud merge

    @MainActor
    func testMergeUnionsByIDAndStaysChronological() {
        let early = SessionRecord(exerciseID: "overhead-reach",
                                  date: Date(timeIntervalSinceNow: -7200),
                                  durationSeconds: 60, averageMatchScore: nil)
        let late = SessionRecord(exerciseID: "neck-side-stretch",
                                 date: Date(timeIntervalSinceNow: -600),
                                 durationSeconds: 30, averageMatchScore: nil)
        let remoteOnly = SessionRecord(exerciseID: "torso-twist",
                                       date: Date(timeIntervalSinceNow: -3600),
                                       durationSeconds: 45, averageMatchScore: 0.8)
        let store = SessionStore(testRecords: [early, late])

        // Remote holds one duplicate and one new record.
        XCTAssertTrue(store.merge(remote: [early, remoteOnly]))
        XCTAssertEqual(store.records.count, 3, "duplicate must not be re-added")
        XCTAssertEqual(store.records.map(\.exerciseID),
                       ["overhead-reach", "torso-twist", "neck-side-stretch"],
                       "merged history must stay date-ordered")

        // Merging the same remote again changes nothing.
        XCTAssertFalse(store.merge(remote: [early, remoteOnly]))
        XCTAssertEqual(store.records.count, 3)
    }

    @MainActor
    func testMergeWithEmptyRemoteIsANoOp() {
        let record = SessionRecord(exerciseID: "overhead-reach", date: Date(),
                                   durationSeconds: 60, averageMatchScore: nil)
        let store = SessionStore(testRecords: [record])
        XCTAssertFalse(store.merge(remote: []))
        XCTAssertEqual(store.records.count, 1)
    }

    // MARK: Weekly summary

    @MainActor
    func testWeeklySummaryAggregatesTrailingSevenDays() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        func record(daysAgo: Int, id: String, seconds: Double, score: Double?) -> SessionRecord {
            SessionRecord(exerciseID: id,
                          date: cal.date(byAdding: .day, value: -daysAgo, to: today)!
                                .addingTimeInterval(3600 * 9),
                          durationSeconds: seconds, averageMatchScore: score)
        }
        let store = SessionStore(testRecords: [
            record(daysAgo: 0, id: "overhead-reach", seconds: 60, score: 0.7),
            record(daysAgo: 0, id: "overhead-reach", seconds: 60, score: 0.9),
            record(daysAgo: 2, id: "neck-side-stretch", seconds: 30, score: nil),
            record(daysAgo: 8, id: "torso-twist", seconds: 300, score: 0.99), // outside window
        ])
        let summary = store.weeklySummary()
        XCTAssertEqual(summary.sessions, 3, "the 8-day-old session is out of the window")
        XCTAssertEqual(summary.minutes, 2.5, accuracy: 0.01)
        XCTAssertEqual(summary.activeDays, 2)
        XCTAssertEqual(summary.topCategory, .fullBody)
        XCTAssertEqual(summary.bestForm ?? 0, 0.9, accuracy: 0.001,
                       "the out-of-window 0.99 must not count")
        XCTAssertEqual(summary.dayCounts.count, 7)
        XCTAssertEqual(summary.dayCounts[6], 2, "today is the last bucket")
        XCTAssertEqual(summary.dayCounts[4], 1)
    }

    @MainActor
    func testWeeklySummaryEmptyHistory() {
        let store = SessionStore(testRecords: [])
        let summary = store.weeklySummary()
        XCTAssertEqual(summary.sessions, 0)
        XCTAssertNil(summary.topCategory)
        XCTAssertNil(summary.bestForm)
        XCTAssertEqual(summary.dayCounts, Array(repeating: 0, count: 7))
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
