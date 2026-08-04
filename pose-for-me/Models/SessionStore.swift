import Combine
import Foundation

/// One completed stretch session.
struct SessionRecord: Codable, Identifiable, Sendable {
    var id = UUID()
    var exerciseID: String
    var date: Date
    var durationSeconds: Double
    var averageMatchScore: Double? // nil for timer-only sessions

    var exercise: Exercise? { Exercise.byID(exerciseID) }
}

/// Aggregate of the trailing 7 days, for the weekly recap card and share image.
struct WeeklySummary: Equatable {
    var sessions = 0
    var minutes = 0.0
    var activeDays = 0
    var topCategory: ExerciseCategory?
    var bestForm: Double?
    /// Sessions per day, oldest first (index 6 = today).
    var dayCounts: [Int] = Array(repeating: 0, count: 7)
}

/// History + streak bookkeeping, persisted as JSON in Application Support.
@MainActor
final class SessionStore: ObservableObject {
    // Xcode 26.2's Swift runtime intermittently aborts in the isolated-deinit
    // executor hop (malloc abort in TaskLocal scope) when MainActor classes
    // deallocate. Deinit only releases storage, which is thread-safe, so opt
    // out of isolation and skip the crashing hop entirely.
    nonisolated deinit {}

    @Published private(set) var records: [SessionRecord] = []

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("sessions.json")
    }

    init() {
        if let raw = try? Data(contentsOf: Self.fileURL),
           let decoded = try? JSONDecoder().decode([SessionRecord].self, from: raw) {
            records = decoded
        }
    }

    /// In-memory store for unit tests: seeds records and never touches disk.
    init(testRecords: [SessionRecord]) {
        records = testRecords
        persistsToDisk = false
    }

    private var persistsToDisk = true

    func add(_ record: SessionRecord) {
        records.append(record)
        save()
        publishToWidgets()
    }

    /// Union remote backup records into local history (dedup by id, kept
    /// chronological). Returns true when anything new arrived from iCloud.
    @discardableResult
    func merge(remote: [SessionRecord]) -> Bool {
        let known = Set(records.map(\.id))
        let fresh = remote.filter { !known.contains($0.id) }
        guard !fresh.isEmpty else { return false }
        records = (records + fresh).sorted { $0.date < $1.date }
        save()
        publishToWidgets()
        return true
    }

    /// Mirrors streak/today stats to the widget and watch surfaces.
    func publishToWidgets() {
        WidgetBridge.setStats(streakDays: streakDays, todayCount: todayCount)
        WatchSyncService.shared.push()
    }

    private func save() {
        guard persistsToDisk else { return }
        if let raw = try? JSONEncoder().encode(records) {
            try? raw.write(to: Self.fileURL, options: .atomic)
        }
    }

    // MARK: - Derived stats

    var todayCount: Int {
        records.filter { Calendar.current.isDateInToday($0.date) }.count
    }

    var todayMinutes: Double {
        records.filter { Calendar.current.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.durationSeconds } / 60
    }

    /// Consecutive days (ending today or yesterday) with at least one session.
    /// Streak shields bridge fully missed days — see `streakAccounting`.
    var streakDays: Int { streakAccounting().streak }

    /// Shields currently held (earned minus those spent inside the current streak).
    var streakShields: Int { streakAccounting().shields }

    /// One shield per `sessionsPerShield` completed stretches, held up to
    /// `maxShields`. A shield is spent automatically when a day inside the
    /// current streak has no sessions, so one busy day doesn't erase the streak.
    static let sessionsPerShield = 7
    static let maxShields = 3

    /// Walks backward from today; missed days consume shields until none remain.
    /// Derived entirely from `records`, so it needs no extra persisted state.
    private func streakAccounting() -> (streak: Int, shields: Int) {
        let calendar = Calendar.current
        let days = Set(records.map { calendar.startOfDay(for: $0.date) })
        var shields = min(Self.maxShields, records.count / Self.sessionsPerShield)
        guard let earliest = days.min() else { return (0, shields) }

        var cursor = calendar.startOfDay(for: Date())
        if !days.contains(cursor) {
            // Today never costs a shield: the streak survives until midnight.
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                return (0, shields)
            }
            cursor = yesterday
        }
        var streak = 0
        while cursor >= earliest {
            if days.contains(cursor) {
                streak += 1
            } else if shields > 0 {
                shields -= 1
                streak += 1
            } else {
                break
            }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return (streak, shields)
    }

    /// The trailing 7 days rolled up for the weekly recap.
    func weeklySummary(now: Date = Date()) -> WeeklySummary {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        guard let windowStart = calendar.date(byAdding: .day, value: -6, to: today) else {
            return WeeklySummary()
        }
        let week = records.filter { $0.date >= windowStart }
        var summary = WeeklySummary()
        summary.sessions = week.count
        summary.minutes = week.reduce(0) { $0 + $1.durationSeconds } / 60

        var byCategory: [ExerciseCategory: Int] = [:]
        for record in week {
            let day = calendar.startOfDay(for: record.date)
            let offset = calendar.dateComponents([.day], from: windowStart, to: day).day ?? 0
            if (0..<7).contains(offset) { summary.dayCounts[offset] += 1 }
            if let category = record.exercise?.category { byCategory[category, default: 0] += 1 }
            if let score = record.averageMatchScore {
                summary.bestForm = max(summary.bestForm ?? 0, score)
            }
        }
        summary.activeDays = summary.dayCounts.filter { $0 > 0 }.count
        summary.topCategory = byCategory
            .sorted { $0.value == $1.value ? $0.key.rawValue < $1.key.rawValue : $0.value > $1.value }
            .first?.key
        return summary
    }

    /// Lifetime sessions and minutes per category, most-stretched first.
    func categoryTotals() -> [(category: ExerciseCategory, count: Int, minutes: Double)] {
        var buckets: [ExerciseCategory: (count: Int, seconds: Double)] = [:]
        for record in records {
            guard let category = record.exercise?.category else { continue }
            var bucket = buckets[category] ?? (0, 0)
            bucket.count += 1
            bucket.seconds += record.durationSeconds
            buckets[category] = bucket
        }
        return buckets
            .map { (category: $0.key, count: $0.value.count, minutes: $0.value.seconds / 60) }
            .sorted {
                $0.count == $1.count ? $0.category.rawValue < $1.category.rawValue
                                     : $0.count > $1.count
            }
    }

    /// Most-stretched exercises with each one's best form score, most first.
    func exerciseTotals() -> [(exercise: Exercise, count: Int, bestForm: Double?)] {
        var buckets: [String: (count: Int, best: Double?)] = [:]
        for record in records {
            var bucket = buckets[record.exerciseID] ?? (0, nil)
            bucket.count += 1
            if let score = record.averageMatchScore {
                bucket.best = max(bucket.best ?? 0, score)
            }
            buckets[record.exerciseID] = bucket
        }
        return buckets
            .compactMap { id, value -> (exercise: Exercise, count: Int, bestForm: Double?)? in
                guard let exercise = Exercise.byID(id) else { return nil }
                return (exercise: exercise, count: value.count, bestForm: value.best)
            }
            .sorted {
                $0.count == $1.count ? $0.exercise.name < $1.exercise.name
                                     : $0.count > $1.count
            }
    }

    /// Sessions-per-day for the last `days` days (oldest first), for the stats chart.
    func dailyCounts(days: Int) -> [(day: Date, count: Int, minutes: Double)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<days).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let dayRecords = records.filter { calendar.isDate($0.date, inSameDayAs: day) }
            let minutes = dayRecords.reduce(0) { $0 + $1.durationSeconds } / 60
            return (day, dayRecords.count, minutes)
        }
    }
}
