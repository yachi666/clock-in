import Foundation

struct PresenceRules {
    private let debounceInterval: TimeInterval
    private let calendar: Calendar

    init(debounceInterval: TimeInterval = 10 * 60, calendar: Calendar = .current) {
        self.debounceInterval = debounceInterval
        self.calendar = calendar
    }

    func validate(candidate event: PresenceEvent, at now: Date) -> PresenceValidationResult {
        now.timeIntervalSince(event.occurredAt) >= debounceInterval ? .validated(event) : .pending
    }

    func attendanceDayIdentifier(forExitAt date: Date) -> String {
        let hour = calendar.component(.hour, from: date)
        let attributedDate = hour < 4 ? calendar.date(byAdding: .day, value: -1, to: date)! : date
        return dayIdentifier(for: attributedDate, calendar: calendar)
    }

    func buildAttendanceDay(arrivedAt: Date, leftAt: Date?) -> AttendanceDay {
        let identifier = dayIdentifier(for: arrivedAt, calendar: calendar)
        let duration = leftAt.map { max(0, $0.timeIntervalSince(arrivedAt)) } ?? 0
        return AttendanceDay(
            dayIdentifier: identifier,
            arrivedAt: arrivedAt,
            leftAt: leftAt,
            totalDuration: duration,
            status: leftAt.map { arrivedAt <= $0 } == true ? .present : .pending
        )
    }
}

func dayIdentifier(for date: Date, calendar: Calendar = .current) -> String {
    let components = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", components.year!, components.month!, components.day!)
}
