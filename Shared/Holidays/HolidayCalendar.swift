import Foundation

struct HolidayCalendar: Codable, Equatable {
    var year: Int
    var region: String
    var entries: [HolidayEntry]

    private enum CodingKeys: String, CodingKey {
        case year
        case region
        case entries = "dates"
    }

    init(year: Int, region: String, entries: [HolidayEntry]) {
        self.year = year
        self.region = region
        self.entries = entries
    }

    func isWorkday(_ dayIdentifier: String, calendar: Calendar = .gregorianCN) throws -> Bool {
        if let override = entries.first(where: { $0.date == dayIdentifier }) {
            switch override.type {
            case .publicHoliday:
                return false
            case .transferWorkday:
                return true
            }
        }

        let date = try DateParser.date(from: dayIdentifier, calendar: calendar)
        let weekday = calendar.component(.weekday, from: date)
        return weekday != 1 && weekday != 7
    }
}

struct HolidayEntry: Codable, Equatable {
    var date: String
    var name: String
    var type: HolidayEntryType
}

enum HolidayEntryType: String, Codable, Equatable {
    case publicHoliday = "public_holiday"
    case transferWorkday = "transfer_workday"
}

enum HolidayCalendarError: Error, Equatable {
    case invalidDate(String)
}

enum DateParser {
    static func date(from dayIdentifier: String, calendar: Calendar) throws -> Date {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dayIdentifier) else {
            throw HolidayCalendarError.invalidDate(dayIdentifier)
        }
        return date
    }
}

extension Calendar {
    static var gregorianCN: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }
}
