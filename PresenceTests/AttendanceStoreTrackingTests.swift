import XCTest
import SwiftData
@testable import Presence

@MainActor
final class AttendanceStoreTrackingTests: XCTestCase {

    private var container: ModelContainer!
    private var store: AttendanceStore!
    private var calendar: Calendar!

    override func setUp() async throws {
        try await super.setUp()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        calendar = cal

        let schema = Schema([
            WorkplaceConfigModel.self,
            RegionEventModel.self,
            AttendanceDayModel.self,
            HolidayCalendarCacheModel.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
        store = AttendanceStore(context: ModelContext(container), rules: PresenceRules(calendar: cal))
    }

    override func tearDown() async throws {
        store = nil
        container = nil
        calendar = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 9, minute: Int = 0) throws -> Date {
        try XCTUnwrap(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)))
    }

    private func fetchDays(inMonth month: Date) throws -> [AttendanceDayModel] {
        try store.fetchAttendanceDays(inMonth: month, calendar: calendar)
    }

    // MARK: - Tests

    /// A validated enter event must create a pending AttendanceDay for the enter date.
    func testValidatedEnterCreatesPendingAttendanceDay() async throws {
        let arrivedAt = try date(2026, 5, 1, hour: 9, minute: 12)

        try await store.save(PresenceEvent(kind: .enter, occurredAt: arrivedAt))

        let days = try fetchDays(inMonth: try date(2026, 5, 1))
        XCTAssertEqual(days.count, 1)
        let day = try XCTUnwrap(days.first)
        XCTAssertEqual(day.dayIdentifier, "2026-05-01")
        XCTAssertEqual(day.arrivedAt, arrivedAt)
        XCTAssertNil(day.leftAt)
        XCTAssertEqual(day.statusRawValue, AttendanceStatus.pending.rawValue)
    }

    /// A validated enter followed by a validated exit must produce a present AttendanceDay
    /// with correct arrivedAt, leftAt, and duration.
    func testValidatedEnterThenExitCreatesPresentAttendanceDay() async throws {
        let arrivedAt = try date(2026, 5, 1, hour: 9, minute: 12)
        let leftAt = try date(2026, 5, 1, hour: 18, minute: 45)

        try await store.save(PresenceEvent(kind: .enter, occurredAt: arrivedAt))
        try await store.save(PresenceEvent(kind: .exit, occurredAt: leftAt))

        let days = try fetchDays(inMonth: try date(2026, 5, 1))
        XCTAssertEqual(days.count, 1)
        let day = try XCTUnwrap(days.first)
        XCTAssertEqual(day.dayIdentifier, "2026-05-01")
        XCTAssertEqual(day.arrivedAt, arrivedAt)
        XCTAssertEqual(day.leftAt, leftAt)
        XCTAssertEqual(day.totalDuration, 9 * 3600 + 33 * 60, accuracy: 1)
        XCTAssertEqual(day.statusRawValue, AttendanceStatus.present.rawValue)
    }

    /// An exit that occurs before 04:00 must be attributed to the previous calendar day.
    func testExitBefore4AMIsAttributedToPreviousDay() async throws {
        let arrivedAt = try date(2026, 5, 1, hour: 22, minute: 0)
        let leftAt   = try date(2026, 5, 2, hour: 3, minute: 30)

        try await store.save(PresenceEvent(kind: .enter, occurredAt: arrivedAt))
        try await store.save(PresenceEvent(kind: .exit, occurredAt: leftAt))

        // The whole month of May should have exactly one day, attributed to May 1.
        let mayDays = try fetchDays(inMonth: try date(2026, 5, 1))
        XCTAssertEqual(mayDays.count, 1, "Only one attendance day should exist")
        let day = try XCTUnwrap(mayDays.first)
        XCTAssertEqual(day.dayIdentifier, "2026-05-01", "Exit before 04:00 must be attributed to the previous day")
        XCTAssertEqual(day.statusRawValue, AttendanceStatus.present.rawValue)
        XCTAssertEqual(day.arrivedAt, arrivedAt)
        XCTAssertEqual(day.leftAt, leftAt)
    }

    /// A later same-day enter must not overwrite an already present AttendanceDay back to pending.
    func testLaterSameDayEnterDoesNotOverwritePresentDay() async throws {
        let firstEnter = try date(2026, 5, 1, hour: 9, minute: 0)
        let exitTime   = try date(2026, 5, 1, hour: 18, minute: 0)
        let laterEnter = try date(2026, 5, 1, hour: 19, minute: 0)

        try await store.save(PresenceEvent(kind: .enter, occurredAt: firstEnter))
        try await store.save(PresenceEvent(kind: .exit, occurredAt: exitTime))
        try await store.save(PresenceEvent(kind: .enter, occurredAt: laterEnter))

        let days = try fetchDays(inMonth: try date(2026, 5, 1))
        XCTAssertEqual(days.count, 1)
        let day = try XCTUnwrap(days.first)
        XCTAssertEqual(day.statusRawValue, AttendanceStatus.present.rawValue, "Day must remain present")
        XCTAssertEqual(day.arrivedAt, firstEnter, "Earliest arrival must be preserved")
        XCTAssertEqual(day.leftAt, exitTime, "leftAt must not be cleared by a later enter")
    }
}
