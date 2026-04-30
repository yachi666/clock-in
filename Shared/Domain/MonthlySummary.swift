import Foundation

enum MonthlySummaryError: Error, Equatable {
    case invalidMonthIdentifier(String)
}

struct MonthlySummary: Equatable {
    let monthIdentifier: String
    let presentDays: Int
    let workingDays: Int

    /// - Throws: `MonthlySummaryError` for invalid month identifiers and
    ///   propagates holiday calendar parsing errors while counting workdays.
    init(
        monthIdentifier: String,
        attendanceDays: [AttendanceDay],
        holidayCalendar: HolidayCalendar,
        calendar: Calendar = .gregorianCN
    ) throws {
        let parts = monthIdentifier.split(separator: "-")
        guard parts.count == 2,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              month >= 1, month <= 12
        else {
            throw MonthlySummaryError.invalidMonthIdentifier(monthIdentifier)
        }

        var firstDayComponents = DateComponents()
        firstDayComponents.year = year
        firstDayComponents.month = month
        firstDayComponents.day = 1
        guard let firstDay = calendar.date(from: firstDayComponents),
              let dayRange = calendar.range(of: .day, in: .month, for: firstDay)
        else {
            throw MonthlySummaryError.invalidMonthIdentifier(monthIdentifier)
        }

        self.monthIdentifier = monthIdentifier
        self.presentDays = attendanceDays.filter { $0.status == .present }.count

        var count = 0
        for day in dayRange {
            let identifier = String(format: "%04d-%02d-%02d", year, month, day)
            if try holidayCalendar.isWorkday(identifier, calendar: calendar) {
                count += 1
            }
        }
        self.workingDays = count
    }
}
