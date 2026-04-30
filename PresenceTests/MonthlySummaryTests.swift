import XCTest
@testable import Presence

final class MonthlySummaryTests: XCTestCase {

    // a. 2026-04: 22 working days with empty holiday calendar; present days counted from .present status
    func testApril2026WorkingDaysAndPresentCount() throws {
        let calendar = HolidayCalendar(year: 2026, region: "CN", entries: [])
        let attendanceDays: [AttendanceDay] = [
            AttendanceDay(dayIdentifier: "2026-04-01", totalDuration: 3600, status: .present),
            AttendanceDay(dayIdentifier: "2026-04-02", totalDuration: 3600, status: .present),
            AttendanceDay(dayIdentifier: "2026-04-03", totalDuration: 0,    status: .absent),
            AttendanceDay(dayIdentifier: "2026-04-06", totalDuration: 0,    status: .pending)
        ]

        let summary = try MonthlySummary(
            monthIdentifier: "2026-04",
            attendanceDays: attendanceDays,
            holidayCalendar: calendar
        )

        XCTAssertEqual(summary.workingDays, 22)
        XCTAssertEqual(summary.presentDays, 2)
        XCTAssertEqual(summary.monthIdentifier, "2026-04")
    }

    // b. Public holiday override reduces working-day count
    func testPublicHolidayReducesWorkingDays() throws {
        let calendar = HolidayCalendar(
            year: 2026,
            region: "CN",
            entries: [HolidayEntry(date: "2026-04-06", name: "Test Holiday", type: .publicHoliday)]
        )

        let summary = try MonthlySummary(
            monthIdentifier: "2026-04",
            attendanceDays: [],
            holidayCalendar: calendar
        )

        XCTAssertEqual(summary.workingDays, 21)
    }

    // c. Transfer workday override increases working-day count when a weekend is marked workday
    func testTransferWorkdayIncreasesWorkingDays() throws {
        // 2026-04-04 is a Saturday (weekend)
        let calendar = HolidayCalendar(
            year: 2026,
            region: "CN",
            entries: [HolidayEntry(date: "2026-04-04", name: "Make-up Workday", type: .transferWorkday)]
        )

        let summary = try MonthlySummary(
            monthIdentifier: "2026-04",
            attendanceDays: [],
            holidayCalendar: calendar
        )

        XCTAssertEqual(summary.workingDays, 23)
    }

    // d. Invalid month identifier throws
    func testInvalidMonthIdentifierThrows() {
        let calendar = HolidayCalendar(year: 2026, region: "CN", entries: [])

        XCTAssertThrowsError(
            try MonthlySummary(monthIdentifier: "not-a-month", attendanceDays: [], holidayCalendar: calendar)
        ) { error in
            XCTAssertEqual(error as? MonthlySummaryError, .invalidMonthIdentifier("not-a-month"))
        }

        XCTAssertThrowsError(
            try MonthlySummary(monthIdentifier: "2026-13", attendanceDays: [], holidayCalendar: calendar)
        ) { error in
            XCTAssertEqual(error as? MonthlySummaryError, .invalidMonthIdentifier("2026-13"))
        }

        XCTAssertThrowsError(
            try MonthlySummary(monthIdentifier: "", attendanceDays: [], holidayCalendar: calendar)
        ) { error in
            XCTAssertEqual(error as? MonthlySummaryError, .invalidMonthIdentifier(""))
        }
    }

    func testEquatable() throws {
        let hc = HolidayCalendar(year: 2026, region: "CN", entries: [])
        let s1 = try MonthlySummary(monthIdentifier: "2026-04", attendanceDays: [], holidayCalendar: hc)
        let s2 = try MonthlySummary(monthIdentifier: "2026-04", attendanceDays: [], holidayCalendar: hc)
        XCTAssertEqual(s1, s2)
    }
}
