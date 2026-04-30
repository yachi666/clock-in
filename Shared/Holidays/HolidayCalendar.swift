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
            case .unknown:
                break
            }
        }

        let date = try DateParser.date(from: dayIdentifier, calendar: calendar)
        let weekday = calendar.component(.weekday, from: date)
        return weekday != 1 && weekday != 7
    }
}

struct HolidayEntry: Equatable {
    var date: String
    var name: String
    var type: HolidayEntryType
}

enum HolidayEntryType: String, Codable, Equatable {
    case publicHoliday = "public_holiday"
    case transferWorkday = "transfer_workday"
    case unknown
}

extension HolidayEntry: Codable {
    private enum CodingKeys: String, CodingKey {
        case date
        case name
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decode(String.self, forKey: .date)
        name = try container.decode(String.self, forKey: .name)
        type = (try? container.decode(HolidayEntryType.self, forKey: .type)) ?? .unknown
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(date, forKey: .date)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
    }
}

enum HolidayCalendarError: Error, Equatable {
    case invalidDate(String)
}

enum DateParser {
    private static let lock = NSLock()
    private static let parser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = .gregorianCN
        formatter.timeZone = Calendar.gregorianCN.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter
    }()

    static func date(from dayIdentifier: String, calendar: Calendar) throws -> Date {
        try Self.lock.withLock {
            Self.parser.calendar = calendar
            Self.parser.timeZone = calendar.timeZone
            guard let date = Self.parser.date(from: dayIdentifier) else {
                throw HolidayCalendarError.invalidDate(dayIdentifier)
            }
            return date
        }
    }
}

extension Calendar {
    static let gregorianCN: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }()
}
