import XCTest
@testable import pose_for_me

final class ReminderSchedulerTests: XCTestCase {

    /// upcomingSlots uses Calendar.current internally, so tests must construct
    /// dates in the same calendar to stay deterministic on any machine.
    private var calendar: Calendar { .current }

    /// Wednesday 2026-07-15 at the given time.
    private func date(_ hour: Int, _ minute: Int = 0, day: Int = 15) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: day,
                                           hour: hour, minute: minute))!
    }

    private func settings(start: (Int, Int), end: (Int, Int),
                          days: Set<Int> = [1, 2, 3, 4, 5, 6, 7],
                          interval: Int = 60) -> SettingsData {
        var s = SettingsData()
        s.activeStartHour = start.0
        s.activeStartMinute = start.1
        s.activeEndHour = end.0
        s.activeEndMinute = end.1
        s.activeWeekdays = days
        s.reminderIntervalMinutes = interval
        return s
    }

    // MARK: Daytime windows

    func testDaytimeWindow() {
        let s = settings(start: (9, 0), end: (18, 0))
        XCTAssertTrue(ReminderScheduler.isActive(date(12), settings: s, calendar: calendar))
        XCTAssertTrue(ReminderScheduler.isActive(date(9), settings: s, calendar: calendar))
        XCTAssertFalse(ReminderScheduler.isActive(date(18), settings: s, calendar: calendar),
                       "end boundary is exclusive")
        XCTAssertFalse(ReminderScheduler.isActive(date(2), settings: s, calendar: calendar))
        XCTAssertFalse(ReminderScheduler.isActive(date(22), settings: s, calendar: calendar))
    }

    func testMinutePrecisionBoundaries() {
        let s = settings(start: (9, 30), end: (17, 45))
        XCTAssertFalse(ReminderScheduler.isActive(date(9, 29), settings: s, calendar: calendar))
        XCTAssertTrue(ReminderScheduler.isActive(date(9, 30), settings: s, calendar: calendar))
        XCTAssertTrue(ReminderScheduler.isActive(date(17, 44), settings: s, calendar: calendar))
        XCTAssertFalse(ReminderScheduler.isActive(date(17, 45), settings: s, calendar: calendar))
    }

    // MARK: Overnight windows (night shift)

    func testOvernightWindowWrapsMidnight() {
        let s = settings(start: (22, 30), end: (5, 45))
        XCTAssertTrue(ReminderScheduler.isActive(date(23), settings: s, calendar: calendar))
        XCTAssertTrue(ReminderScheduler.isActive(date(2), settings: s, calendar: calendar))
        XCTAssertTrue(ReminderScheduler.isActive(date(5, 44), settings: s, calendar: calendar))
        XCTAssertFalse(ReminderScheduler.isActive(date(5, 45), settings: s, calendar: calendar))
        XCTAssertFalse(ReminderScheduler.isActive(date(12), settings: s, calendar: calendar))
        XCTAssertFalse(ReminderScheduler.isActive(date(22, 29), settings: s, calendar: calendar))
    }

    func testOvernightEarlyMorningBelongsToPreviousDayShift() {
        // Active Wednesday only (weekday 4). July 15 2026 is a Wednesday.
        let s = settings(start: (22, 0), end: (6, 0), days: [4])
        // Wednesday 23:00 — inside Wednesday's shift.
        XCTAssertTrue(ReminderScheduler.isActive(date(23, 0, day: 15), settings: s, calendar: calendar))
        // Thursday 03:00 — still Wednesday's shift.
        XCTAssertTrue(ReminderScheduler.isActive(date(3, 0, day: 16), settings: s, calendar: calendar))
        // Wednesday 03:00 — that's Tuesday's shift, which is off.
        XCTAssertFalse(ReminderScheduler.isActive(date(3, 0, day: 15), settings: s, calendar: calendar))
    }

    // MARK: Around the clock

    func testEqualStartAndEndMeansAlwaysActive() {
        let s = settings(start: (9, 0), end: (9, 0))
        XCTAssertTrue(ReminderScheduler.isActive(date(0), settings: s, calendar: calendar))
        XCTAssertTrue(ReminderScheduler.isActive(date(12), settings: s, calendar: calendar))
        XCTAssertTrue(ReminderScheduler.isActive(date(23, 59), settings: s, calendar: calendar))
    }

    func testInactiveWeekdayBlocksAllDay() {
        let s = settings(start: (9, 0), end: (18, 0), days: [2]) // Mondays only
        XCTAssertFalse(ReminderScheduler.isActive(date(12), settings: s, calendar: calendar),
                       "Wednesday must be inactive when only Monday is enabled")
    }

    // MARK: Slot generation

    @MainActor
    func testSlotsRespectIntervalInsideWindow() {
        let scheduler = ReminderScheduler()
        let s = settings(start: (9, 0), end: (18, 0), interval: 60)
        let from = date(10) // inside the window
        let slots = scheduler.upcomingSlots(settings: s, count: 3, from: from)
        XCTAssertEqual(slots.count, 3)
        XCTAssertEqual(slots[0].timeIntervalSince(from), 3600, accuracy: 1)
        XCTAssertEqual(slots[1].timeIntervalSince(slots[0]), 3600, accuracy: 1)
    }

    @MainActor
    func testSlotsSkipToNextWindowWhenOutside() {
        let scheduler = ReminderScheduler()
        let s = settings(start: (9, 0), end: (18, 0), interval: 60)
        let from = date(20) // after hours
        let slots = scheduler.upcomingSlots(settings: s, count: 1, from: from)
        XCTAssertEqual(slots.count, 1)
        // First nudge lands one interval into the next day's window: 10:00.
        let comps = calendar.dateComponents([.day, .hour, .minute], from: slots[0])
        XCTAssertEqual(comps.day, 16)
        XCTAssertEqual(comps.hour, 10)
        XCTAssertEqual(comps.minute, 0)
    }

    @MainActor
    func testSlotsForOvernightShiftCrossMidnight() {
        let scheduler = ReminderScheduler()
        let s = settings(start: (22, 0), end: (6, 0), interval: 120)
        let from = date(22, 30) // inside tonight's shift
        let slots = scheduler.upcomingSlots(settings: s, count: 2, from: from)
        XCTAssertEqual(slots.count, 2)
        // 00:30 and 02:30 the next calendar day.
        let c0 = calendar.dateComponents([.day, .hour, .minute], from: slots[0])
        XCTAssertEqual(c0.day, 16); XCTAssertEqual(c0.hour, 0); XCTAssertEqual(c0.minute, 30)
        let c1 = calendar.dateComponents([.day, .hour, .minute], from: slots[1])
        XCTAssertEqual(c1.day, 16); XCTAssertEqual(c1.hour, 2); XCTAssertEqual(c1.minute, 30)
    }

    @MainActor
    func testNoActiveDaysYieldsNoSlots() {
        let scheduler = ReminderScheduler()
        let s = settings(start: (9, 0), end: (18, 0), days: [])
        let slots = scheduler.upcomingSlots(settings: s, count: 5, from: date(10))
        XCTAssertTrue(slots.isEmpty)
    }
}
