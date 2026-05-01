import XCTest
@testable import Presence

final class DashboardCalendarLayoutTests: XCTestCase {
    func testAdjacentMonthIdentifiers() {
        XCTAssertEqual(DashboardMonthNavigator.previousMonth(from: "2026-04"), "2026-03")
        XCTAssertEqual(DashboardMonthNavigator.nextMonth(from: "2026-04"), "2026-05")
        XCTAssertEqual(DashboardMonthNavigator.previousMonth(from: "2026-01"), "2025-12")
        XCTAssertEqual(DashboardMonthNavigator.nextMonth(from: "2026-12"), "2027-01")
    }

    func testSwipeResolverOnlyChangesMonthForIntentionalHorizontalSwipes() {
        XCTAssertEqual(DashboardMonthSwipeResolver.change(for: CGSize(width: -88, height: 8)), .next)
        XCTAssertEqual(DashboardMonthSwipeResolver.change(for: CGSize(width: 88, height: -8)), .previous)
        XCTAssertNil(DashboardMonthSwipeResolver.change(for: CGSize(width: -24, height: 0)))
        XCTAssertNil(DashboardMonthSwipeResolver.change(for: CGSize(width: -88, height: 120)))
    }

    func testHitTestingCalendarCellsMapsPointToDay() throws {
        let days = (0..<35).map { index in
            DashboardCalendarDay(
                id: "day-\(index)",
                date: index + 1,
                identifier: "2026-04-\(index + 1)",
                status: .future,
                isCurrentMonth: true,
                attendance: nil
            )
        }

        XCTAssertEqual(
            DashboardCalendarHitTester.day(at: CGPoint(x: 10, y: 10), in: CGSize(width: 350, height: 250), days: days)?.id,
            "day-0"
        )
        XCTAssertEqual(
            DashboardCalendarHitTester.day(at: CGPoint(x: 349, y: 249), in: CGSize(width: 350, height: 250), days: days)?.id,
            "day-34"
        )
        XCTAssertNil(DashboardCalendarHitTester.day(at: CGPoint(x: -1, y: 10), in: CGSize(width: 350, height: 250), days: days))
    }

    func testCalendarCellFrameMatchesHitTestingGrid() throws {
        let days = (0..<35).map { index in
            DashboardCalendarDay(
                id: "day-\(index)",
                date: index + 1,
                identifier: "2026-04-\(index + 1)",
                status: .future,
                isCurrentMonth: true,
                attendance: nil
            )
        }

        let frame = try XCTUnwrap(
            DashboardCalendarHitTester.frame(for: "day-8", in: CGSize(width: 350, height: 250), days: days)
        )

        XCTAssertEqual(frame, CGRect(x: 50, y: 50, width: 50, height: 50))
    }

    func testPopoverPositionAnchorsNearDayAndAvoidsEdges() {
        let containerSize = CGSize(width: 390, height: 700)
        let popoverSize = CGSize(width: 220, height: 118)

        let topDayFrame = CGRect(x: 0, y: 8, width: 50, height: 34)
        XCTAssertEqual(
            DashboardPopoverPositioner.position(
                anchoredTo: topDayFrame,
                popoverSize: popoverSize,
                containerSize: containerSize
            ),
            CGPoint(x: 134, y: 113)
        )

        let lowerDayFrame = CGRect(x: 170, y: 240, width: 50, height: 34)
        XCTAssertEqual(
            DashboardPopoverPositioner.position(
                anchoredTo: lowerDayFrame,
                popoverSize: popoverSize,
                containerSize: containerSize
            ),
            CGPoint(x: 195, y: 169)
        )
    }

    func testMonthTitlePartsRejectInvalidMonthInsteadOfCrashing() {
        XCTAssertEqual(
            DashboardMonthTitleParts.parts(from: "2026-13").month,
            "2026-13"
        )
    }

    func testBuildMarksTodayInCurrentMonth() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!

        let today = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 4, day: 16)))
        let days = DashboardCalendarLayout.build(
            monthIdentifier: "2026-04",
            attendanceDays: [],
            calendar: calendar,
            today: today
        )

        XCTAssertEqual(days.filter(\.isToday).map(\.identifier), ["2026-04-16"])
    }

    func testBuildMarksHolidayEntriesForCalendarDays() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!

        let today = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 1)))
        let holidayCalendar = HolidayCalendar(year: 2026, region: "CN", entries: [
            HolidayEntry(date: "2026-05-01", name: "劳动节", type: .publicHoliday),
            HolidayEntry(date: "2026-05-09", name: "补班", type: .transferWorkday)
        ])

        let days = DashboardCalendarLayout.build(
            monthIdentifier: "2026-05",
            attendanceDays: [],
            holidayCalendar: holidayCalendar,
            calendar: calendar,
            today: today
        )

        let holiday = try XCTUnwrap(days.first { $0.identifier == "2026-05-01" }?.holiday)
        XCTAssertEqual(holiday.name, "劳动节")
        XCTAssertEqual(holiday.type, .publicHoliday)

        let workday = try XCTUnwrap(days.first { $0.identifier == "2026-05-09" }?.holiday)
        XCTAssertEqual(workday.name, "补班")
        XCTAssertEqual(workday.type, .transferWorkday)
    }

    func testGestureHintShowsUntilSeen() {
        XCTAssertTrue(DashboardGestureHint.shouldShow(hasSeenHint: false))
        XCTAssertFalse(DashboardGestureHint.shouldShow(hasSeenHint: true))
        XCTAssertEqual(DashboardGestureHint.text, "Hold a date · Swipe month")
    }

    func testSetupMapFocusSitsInVisibleMapAreaAboveBottomCard() {
        XCTAssertEqual(
            SetupMapFocusLayout.markerY(in: CGSize(width: 390, height: 800)),
            240
        )
    }

    func testSetupMapFocusStaysInsideSmallVisibleMapArea() {
        let markerY = SetupMapFocusLayout.markerY(in: CGSize(width: 390, height: 400))

        XCTAssertLessThanOrEqual(markerY, 80)
        XCTAssertGreaterThanOrEqual(markerY, 0)
    }

    func testBuildsFigmaStyleCalendarStatesFromRealAttendance() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!

        let today = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 4, day: 16)))
        let days = DashboardCalendarLayout.build(
            monthIdentifier: "2026-04",
            attendanceDays: [
                AttendanceDay(dayIdentifier: "2026-04-15", arrivedAt: try date(calendar, 2026, 4, 15, 9, 5), leftAt: try date(calendar, 2026, 4, 15, 18, 30), totalDuration: 33_900, status: .present),
                AttendanceDay(dayIdentifier: "2026-04-16", arrivedAt: try date(calendar, 2026, 4, 16, 9, 10), leftAt: nil, totalDuration: 0, status: .pending)
            ],
            calendar: calendar,
            today: today
        )

        XCTAssertEqual(days.count, 35)
        XCTAssertEqual(days.prefix(3).map(\.status), [.empty, .empty, .empty])

        let presentDay = try XCTUnwrap(days.first { $0.identifier == "2026-04-15" })
        XCTAssertEqual(presentDay.status, .present)
        XCTAssertEqual(presentDay.attendance?.leftAt, try date(calendar, 2026, 4, 15, 18, 30))

        let incompleteDay = try XCTUnwrap(days.first { $0.identifier == "2026-04-16" })
        XCTAssertEqual(incompleteDay.status, .incomplete)
        XCTAssertEqual(incompleteDay.attendance?.arrivedAt, try date(calendar, 2026, 4, 16, 9, 10))

        let futureDay = try XCTUnwrap(days.first { $0.identifier == "2026-04-17" })
        XCTAssertEqual(futureDay.status, .future)
    }

    func testPopoverStatusLabelsAttendanceStatesBeforeHoliday() {
        let presentDay = DashboardCalendarDay(
            id: "2026-05-01",
            date: 1,
            identifier: "2026-05-01",
            status: .present,
            isCurrentMonth: true,
            holiday: HolidayEntry(date: "2026-05-01", name: "劳动节", type: .publicHoliday),
            attendance: AttendanceDay(
                dayIdentifier: "2026-05-01",
                arrivedAt: Date(timeIntervalSince1970: 1_777_555_200),
                leftAt: Date(timeIntervalSince1970: 1_777_589_400),
                totalDuration: 34_200,
                status: .present
            )
        )

        let pendingDay = DashboardCalendarDay(
            id: "2026-05-02",
            date: 2,
            identifier: "2026-05-02",
            status: .incomplete,
            isCurrentMonth: true,
            attendance: AttendanceDay(
                dayIdentifier: "2026-05-02",
                arrivedAt: Date(timeIntervalSince1970: 1_777_641_600),
                leftAt: nil,
                totalDuration: 0,
                status: .pending
            )
        )

        let absentDay = DashboardCalendarDay(
            id: "2026-05-03",
            date: 3,
            identifier: "2026-05-03",
            status: .incomplete,
            isCurrentMonth: true,
            attendance: AttendanceDay(
                dayIdentifier: "2026-05-03",
                arrivedAt: nil,
                leftAt: nil,
                totalDuration: 0,
                status: .absent
            )
        )

        XCTAssertEqual(DashboardPopoverStatus.status(for: presentDay), .present)
        XCTAssertEqual(DashboardPopoverStatus.status(for: pendingDay), .pending)
        XCTAssertEqual(DashboardPopoverStatus.status(for: absentDay), .pending)
    }

    func testPopoverStatusLabelsHolidayFutureAndNoRecord() {
        let holidayDay = DashboardCalendarDay(
            id: "2026-05-01",
            date: 1,
            identifier: "2026-05-01",
            status: .empty,
            isCurrentMonth: true,
            holiday: HolidayEntry(date: "2026-05-01", name: "劳动节", type: .publicHoliday),
            attendance: nil
        )
        let futureDay = DashboardCalendarDay(
            id: "2026-05-20",
            date: 20,
            identifier: "2026-05-20",
            status: .future,
            isCurrentMonth: true,
            attendance: nil
        )
        let emptyDay = DashboardCalendarDay(
            id: "2026-05-10",
            date: 10,
            identifier: "2026-05-10",
            status: .empty,
            isCurrentMonth: true,
            attendance: nil
        )

        XCTAssertEqual(DashboardPopoverStatus.status(for: holidayDay), .holiday)
        XCTAssertEqual(DashboardPopoverStatus.status(for: futureDay), .future)
        XCTAssertEqual(DashboardPopoverStatus.status(for: emptyDay), .noRecord)
    }

    func testDayVisualSemanticsMapsStatusToQuietHaloMarkers() {
        let presentDay = DashboardCalendarDay(
            id: "2026-05-01",
            date: 1,
            identifier: "2026-05-01",
            status: .present,
            isCurrentMonth: true,
            attendance: AttendanceDay(
                dayIdentifier: "2026-05-01",
                arrivedAt: Date(timeIntervalSince1970: 1_777_555_200),
                leftAt: Date(timeIntervalSince1970: 1_777_589_400),
                totalDuration: 34_200,
                status: .present
            )
        )
        let incompleteDay = DashboardCalendarDay(
            id: "2026-05-02",
            date: 2,
            identifier: "2026-05-02",
            status: .incomplete,
            isCurrentMonth: true,
            attendance: AttendanceDay(
                dayIdentifier: "2026-05-02",
                arrivedAt: Date(timeIntervalSince1970: 1_777_641_600),
                leftAt: nil,
                totalDuration: 0,
                status: .pending
            )
        )
        let futureDay = DashboardCalendarDay(
            id: "2026-05-03",
            date: 3,
            identifier: "2026-05-03",
            status: .future,
            isCurrentMonth: true,
            attendance: nil
        )
        let emptyDay = DashboardCalendarDay(
            id: "2026-05-04",
            date: 4,
            identifier: "2026-05-04",
            status: .empty,
            isCurrentMonth: true,
            attendance: nil
        )

        XCTAssertEqual(DashboardDayVisualSemantics.marker(for: presentDay), .presentSignal)
        XCTAssertEqual(DashboardDayVisualSemantics.marker(for: incompleteDay), .incompleteRing)
        XCTAssertEqual(DashboardDayVisualSemantics.marker(for: futureDay), .futureDot)
        XCTAssertEqual(DashboardDayVisualSemantics.marker(for: emptyDay), .none)

        XCTAssertTrue(DashboardDayVisualSemantics.emphasizesDate(for: presentDay))
        XCTAssertTrue(DashboardDayVisualSemantics.emphasizesDate(for: incompleteDay))
        XCTAssertFalse(DashboardDayVisualSemantics.emphasizesDate(for: futureDay))
        XCTAssertFalse(DashboardDayVisualSemantics.emphasizesDate(for: emptyDay))
    }

    func testDayVisualSemanticsReturnsHolidayBadgeTextAndTone() {
        let holidayDay = DashboardCalendarDay(
            id: "2026-05-01",
            date: 1,
            identifier: "2026-05-01",
            status: .empty,
            isCurrentMonth: true,
            holiday: HolidayEntry(date: "2026-05-01", name: "劳动节", type: .publicHoliday),
            attendance: nil
        )
        let transferWorkday = DashboardCalendarDay(
            id: "2026-05-10",
            date: 10,
            identifier: "2026-05-10",
            status: .empty,
            isCurrentMonth: true,
            holiday: HolidayEntry(date: "2026-05-10", name: "补班", type: .transferWorkday),
            attendance: nil
        )
        let ordinaryDay = DashboardCalendarDay(
            id: "2026-05-12",
            date: 12,
            identifier: "2026-05-12",
            status: .empty,
            isCurrentMonth: true,
            attendance: nil
        )

        XCTAssertEqual(DashboardDayVisualSemantics.badge(for: holidayDay), .label(text: "休", tone: .holiday))
        XCTAssertEqual(DashboardDayVisualSemantics.badge(for: transferWorkday), .label(text: "班", tone: .transferWorkday))
        XCTAssertEqual(DashboardDayVisualSemantics.badge(for: ordinaryDay), .none)
    }

    func testPopoverSizeMatchesVisibleContentBuckets() {
        let attendance = AttendanceDay(
            dayIdentifier: "2026-05-01",
            arrivedAt: Date(timeIntervalSince1970: 1_777_555_200),
            leftAt: Date(timeIntervalSince1970: 1_777_589_400),
            totalDuration: 34_200,
            status: .present
        )
        let holiday = HolidayEntry(date: "2026-05-01", name: "劳动节", type: .publicHoliday)

        XCTAssertEqual(
            DashboardView.popoverSize(for: popoverDay(attendance: attendance, holiday: holiday)),
            CGSize(width: 224, height: 164)
        )
        XCTAssertEqual(
            DashboardView.popoverSize(for: popoverDay(attendance: attendance, holiday: nil)),
            CGSize(width: 224, height: 144)
        )
        XCTAssertEqual(
            DashboardView.popoverSize(for: popoverDay(attendance: nil, holiday: holiday)),
            CGSize(width: 224, height: 116)
        )
        XCTAssertEqual(
            DashboardView.popoverSize(for: popoverDay(attendance: nil, holiday: nil)),
            CGSize(width: 224, height: 96)
        )
    }

    private func popoverDay(attendance: AttendanceDay?, holiday: HolidayEntry?) -> DashboardCalendarDay {
        DashboardCalendarDay(
            id: "2026-05-01",
            date: 1,
            identifier: "2026-05-01",
            status: attendance == nil ? .empty : .present,
            isCurrentMonth: true,
            holiday: holiday,
            attendance: attendance
        )
    }

    private func date(_ calendar: Calendar, _ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) throws -> Date {
        try XCTUnwrap(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)))
    }
}
