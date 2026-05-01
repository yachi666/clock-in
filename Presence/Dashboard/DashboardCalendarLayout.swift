import Foundation
import CoreGraphics

enum DashboardDayStatus: Equatable {
    case present
    case future
    case incomplete
    case empty
}

struct DashboardCalendarDay: Equatable {
    let id: String
    let date: Int
    let identifier: String?
    let status: DashboardDayStatus
    let isCurrentMonth: Bool
    var isToday: Bool = false
    var holiday: HolidayEntry? = nil
    let attendance: AttendanceDay?
}

enum DashboardCalendarLayout {
    static func build(
        monthIdentifier: String,
        attendanceDays: [AttendanceDay],
        holidayCalendar: HolidayCalendar? = nil,
        calendar: Calendar = .gregorianCN,
        today: Date = Date()
    ) -> [DashboardCalendarDay] {
        let parts = monthIdentifier.split(separator: "-")
        guard parts.count == 2,
              let year = Int(parts[0]),
              let month = Int(parts[1])
        else { return [] }

        var firstComponents = DateComponents()
        firstComponents.year = year
        firstComponents.month = month
        firstComponents.day = 1

        guard let firstDay = calendar.date(from: firstComponents),
              let dayRange = calendar.range(of: .day, in: .month, for: firstDay)
        else { return [] }

        let attendanceMap = Dictionary(uniqueKeysWithValues: attendanceDays.map { ($0.dayIdentifier, $0) })
        let holidayMap = Dictionary(uniqueKeysWithValues: (holidayCalendar?.entries ?? []).map { ($0.date, $0) })
        let leadingEmptyDays = calendar.component(.weekday, from: firstDay) - 1
        let totalVisibleDays = max(35, Int(ceil(Double(leadingEmptyDays + dayRange.count) / 7.0)) * 7)

        return (0..<totalVisibleDays).map { index in
            let currentMonthDay = index - leadingEmptyDays + 1
            guard dayRange.contains(currentMonthDay) else {
                return DashboardCalendarDay(
                    id: "empty-\(index)",
                    date: currentMonthDay < 1 ? currentMonthDay + previousMonthDayCount(before: firstDay, calendar: calendar) : currentMonthDay - dayRange.count,
                    identifier: nil,
                    status: .empty,
                    isCurrentMonth: false,
                    attendance: nil
                )
            }

            let identifier = String(format: "%04d-%02d-%02d", year, month, currentMonthDay)
            let attendance = attendanceMap[identifier]
            let status = status(for: attendance, year: year, month: month, day: currentMonthDay, calendar: calendar, today: today)
            let date = calendar.date(from: DateComponents(year: year, month: month, day: currentMonthDay))
            return DashboardCalendarDay(
                id: identifier,
                date: currentMonthDay,
                identifier: identifier,
                status: status,
                isCurrentMonth: true,
                isToday: date.map { calendar.isDate($0, inSameDayAs: today) } ?? false,
                holiday: holidayMap[identifier],
                attendance: attendance
            )
        }
    }

    private static func status(
        for attendance: AttendanceDay?,
        year: Int,
        month: Int,
        day: Int,
        calendar: Calendar,
        today: Date
    ) -> DashboardDayStatus {
        if let attendance {
            switch attendance.status {
            case .present:
                return .present
            case .pending, .absent:
                return .incomplete
            }
        }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        guard let date = calendar.date(from: components) else { return .empty }
        return calendar.startOfDay(for: date) > calendar.startOfDay(for: today) ? .future : .empty
    }

    private static func previousMonthDayCount(before firstDay: Date, calendar: Calendar) -> Int {
        guard let previousMonth = calendar.date(byAdding: .month, value: -1, to: firstDay),
              let range = calendar.range(of: .day, in: .month, for: previousMonth)
        else { return 31 }
        return range.count
    }
}

enum DashboardMonthChange: Equatable {
    case previous
    case next
}

enum DashboardMonthNavigator {
    static func previousMonth(from monthIdentifier: String, calendar: Calendar = .gregorianCN) -> String {
        adjacentMonth(from: monthIdentifier, offset: -1, calendar: calendar)
    }

    static func nextMonth(from monthIdentifier: String, calendar: Calendar = .gregorianCN) -> String {
        adjacentMonth(from: monthIdentifier, offset: 1, calendar: calendar)
    }

    private static func adjacentMonth(from monthIdentifier: String, offset: Int, calendar: Calendar) -> String {
        let parts = monthIdentifier.split(separator: "-")
        guard parts.count == 2,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let date = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let adjacentDate = calendar.date(byAdding: .month, value: offset, to: date)
        else { return monthIdentifier }

        let adjacentYear = calendar.component(.year, from: adjacentDate)
        let adjacentMonth = calendar.component(.month, from: adjacentDate)
        return String(format: "%04d-%02d", adjacentYear, adjacentMonth)
    }
}

enum DashboardMonthTitleParts {
    static func parts(from monthIdentifier: String) -> (month: String, year: String) {
        let parts = monthIdentifier.split(separator: "-")
        guard parts.count == 2,
              let month = Int(parts[1]),
              (1...12).contains(month)
        else {
            return (monthIdentifier, "")
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return (formatter.monthSymbols[month - 1], String(parts[0]))
    }
}

enum DashboardMonthSwipeResolver {
    static func change(for translation: CGSize, threshold: CGFloat = 72) -> DashboardMonthChange? {
        guard abs(translation.width) >= threshold,
              abs(translation.width) > abs(translation.height)
        else { return nil }

        return translation.width < 0 ? .next : .previous
    }
}

enum DashboardGestureHint {
    static let text = "Hold a date · Swipe month"

    static func shouldShow(hasSeenHint: Bool) -> Bool {
        !hasSeenHint
    }
}

enum DashboardPopoverStatus: Equatable {
    case present
    case pending
    case holiday
    case future
    case noRecord

    var label: String {
        switch self {
        case .present:
            return "Present"
        case .pending:
            return "Pending"
        case .holiday:
            return "Holiday"
        case .future:
            return "Future"
        case .noRecord:
            return "No record"
        }
    }

    static func status(for day: DashboardCalendarDay) -> DashboardPopoverStatus {
        if let attendance = day.attendance {
            switch attendance.status {
            case .present:
                return .present
            case .pending, .absent:
                return .pending
            }
        }

        if day.holiday?.type == .publicHoliday {
            return .holiday
        }

        if day.status == .future {
            return .future
        }

        return .noRecord
    }
}

enum DashboardDayMarkerStyle: Equatable {
    case none
    case futureDot
    case incompleteRing
    case presentSignal
}

enum DashboardHolidayBadgeTone: Equatable {
    case holiday
    case transferWorkday
}

enum DashboardHolidayBadgeStyle: Equatable {
    case none
    case label(text: String, tone: DashboardHolidayBadgeTone)
}

enum DashboardDayVisualSemantics {
    static func marker(for day: DashboardCalendarDay) -> DashboardDayMarkerStyle {
        switch day.status {
        case .present:
            return .presentSignal
        case .future:
            return .futureDot
        case .incomplete:
            return .incompleteRing
        case .empty:
            return .none
        }
    }

    static func badge(for day: DashboardCalendarDay) -> DashboardHolidayBadgeStyle {
        guard let holiday = day.holiday else { return .none }

        switch holiday.type {
        case .publicHoliday, .unknown:
            return .label(text: "休", tone: .holiday)
        case .transferWorkday:
            return .label(text: "班", tone: .transferWorkday)
        }
    }

    static func emphasizesDate(for day: DashboardCalendarDay) -> Bool {
        day.status == .present || day.status == .incomplete
    }
}

enum DashboardCalendarHitTester {
    static func day(at point: CGPoint, in size: CGSize, days: [DashboardCalendarDay], columns: Int = 7) -> DashboardCalendarDay? {
        guard point.x >= 0,
              point.y >= 0,
              point.x < size.width,
              point.y < size.height,
              !days.isEmpty,
              columns > 0
        else { return nil }

        let rows = Int(ceil(Double(days.count) / Double(columns)))
        guard rows > 0 else { return nil }

        let column = min(columns - 1, Int(point.x / (size.width / CGFloat(columns))))
        let row = min(rows - 1, Int(point.y / (size.height / CGFloat(rows))))
        let index = row * columns + column
        guard days.indices.contains(index) else { return nil }
        return days[index]
    }

    static func frame(for dayID: String, in size: CGSize, days: [DashboardCalendarDay], columns: Int = 7) -> CGRect? {
        guard let index = days.firstIndex(where: { $0.id == dayID }),
              !days.isEmpty,
              columns > 0
        else { return nil }

        let rows = Int(ceil(Double(days.count) / Double(columns)))
        guard rows > 0 else { return nil }

        let cellWidth = size.width / CGFloat(columns)
        let cellHeight = size.height / CGFloat(rows)
        let column = index % columns
        let row = index / columns

        return CGRect(
            x: CGFloat(column) * cellWidth,
            y: CGFloat(row) * cellHeight,
            width: cellWidth,
            height: cellHeight
        )
    }
}

enum DashboardPopoverPositioner {
    static func position(
        anchoredTo dayFrame: CGRect,
        popoverSize: CGSize,
        containerSize: CGSize,
        topSafeArea: CGFloat = 96,
        margin: CGFloat = 24,
        gap: CGFloat = 12
    ) -> CGPoint {
        let halfWidth = popoverSize.width / 2
        let minX = margin + halfWidth
        let maxX = max(minX, containerSize.width - margin - halfWidth)
        let x = min(max(dayFrame.midX, minX), maxX)

        let halfHeight = popoverSize.height / 2
        let aboveY = dayFrame.minY - gap - halfHeight
        let belowY = dayFrame.maxY + gap + halfHeight
        let preferredY = aboveY >= topSafeArea ? aboveY : belowY
        let maxY = max(topSafeArea, containerSize.height - margin - halfHeight)
        let y = min(max(preferredY, topSafeArea), maxY)

        return CGPoint(x: x, y: y)
    }
}
