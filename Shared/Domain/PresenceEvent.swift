import Foundation

struct PresenceEvent: Codable, Equatable, Hashable {
    enum Kind: String, Codable, Equatable, Hashable {
        case enter
        case exit
    }

    var kind: Kind
    var occurredAt: Date
}

enum PresenceValidationResult: Equatable {
    case pending
    case validated(PresenceEvent)
}

struct AttendanceDay: Equatable {
    var dayIdentifier: String
    var arrivedAt: Date?
    var leftAt: Date?
    var totalDuration: TimeInterval
    var status: AttendanceStatus
}

enum AttendanceStatus: String, Codable, Hashable {
    case present
    case absent
    case pending
}
