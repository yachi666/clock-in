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
        let attributedDate = (hour < 4 ? calendar.date(byAdding: .day, value: -1, to: date) : nil) ?? date
        return dayIdentifier(for: attributedDate, calendar: calendar)
    }

    func buildAttendanceDay(arrivedAt: Date, leftAt: Date?) -> AttendanceDay {
        let validLeftAt = leftAt.flatMap { $0 >= arrivedAt ? $0 : nil }
        let identifier = dayIdentifier(for: arrivedAt, calendar: calendar)
        let duration = validLeftAt.map { $0.timeIntervalSince(arrivedAt) } ?? 0
        return AttendanceDay(
            dayIdentifier: identifier,
            arrivedAt: arrivedAt,
            leftAt: validLeftAt,
            totalDuration: duration,
            status: validLeftAt == nil ? .pending : .present
        )
    }
}
