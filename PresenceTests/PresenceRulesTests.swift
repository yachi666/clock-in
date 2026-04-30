import XCTest
@testable import Presence

final class PresenceRulesTests: XCTestCase {
    func testEnterEventIsPendingBeforeTenMinutes() {
        let calendar = Calendar(identifier: .gregorian)
        let rules = PresenceRules(calendar: calendar)
        let event = PresenceEvent(kind: .enter, occurredAt: Date(timeIntervalSince1970: 1_000))

        let result = rules.validate(candidate: event, at: Date(timeIntervalSince1970: 1_000 + 9 * 60 + 59))

        XCTAssertEqual(result, .pending)
    }

    func testEnterEventIsValidatedAfterTenMinutes() {
        let calendar = Calendar(identifier: .gregorian)
        let rules = PresenceRules(calendar: calendar)
        let event = PresenceEvent(kind: .enter, occurredAt: Date(timeIntervalSince1970: 1_000))

        let result = rules.validate(candidate: event, at: Date(timeIntervalSince1970: 1_000 + 10 * 60))

        XCTAssertEqual(result, .validated(event))
    }

    func testExitBeforeFourAMBelongsToPreviousDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        let rules = PresenceRules(calendar: calendar)
        let exit = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 2, hour: 3, minute: 30)))

        let id = rules.attendanceDayIdentifier(forExitAt: exit)

        XCTAssertEqual(id, "2026-05-01")
    }

    func testBuildAttendanceDayWithoutExitIsPending() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        let rules = PresenceRules(calendar: calendar)
        let arrivedAt = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 1, hour: 9, minute: 12)))

        let day = rules.buildAttendanceDay(arrivedAt: arrivedAt, leftAt: nil)

        XCTAssertEqual(day.dayIdentifier, "2026-05-01")
        XCTAssertEqual(day.status, .pending)
        XCTAssertNil(day.leftAt)
        XCTAssertEqual(day.totalDuration, 0)
    }

    func testBuildAttendanceDayFromValidatedEnterAndExit() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        let rules = PresenceRules(calendar: calendar)
        let arrivedAt = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 1, hour: 9, minute: 12)))
        let leftAt = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 1, hour: 18, minute: 45)))

        let day = rules.buildAttendanceDay(arrivedAt: arrivedAt, leftAt: leftAt)

        XCTAssertEqual(day.dayIdentifier, "2026-05-01")
        XCTAssertEqual(day.status, .present)
        XCTAssertEqual(day.totalDuration, 9 * 3600 + 33 * 60, accuracy: 1)
    }
}
