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

/// History + streak bookkeeping, persisted as JSON in Application Support.
@MainActor
final class SessionStore: ObservableObject {
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

    func add(_ record: SessionRecord) {
        records.append(record)
        save()
    }

    private func save() {
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
    var streakDays: Int {
        let calendar = Calendar.current
        let days = Set(records.map { calendar.startOfDay(for: $0.date) })
        guard !days.isEmpty else { return 0 }

        var cursor = calendar.startOfDay(for: Date())
        if !days.contains(cursor) {
            // Streak survives until the end of today; start counting from yesterday.
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor),
                  days.contains(yesterday) else { return 0 }
            cursor = yesterday
        }
        var streak = 0
        while days.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
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
