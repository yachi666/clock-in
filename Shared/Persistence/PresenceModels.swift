import Foundation
import SwiftData

@Model
final class WorkplaceConfigModel {
    @Attribute(.unique) var singletonKey: String
    var latitude: Double
    var longitude: Double
    var radiusMeters: Double
    var completedSetup: Bool
    var createdAt: Date
    var updatedAt: Date

    init(latitude: Double, longitude: Double, radiusMeters: Double, completedSetup: Bool = true, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.singletonKey = "workplace"
        self.latitude = latitude
        self.longitude = longitude
        self.radiusMeters = radiusMeters
        self.completedSetup = completedSetup
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class RegionEventModel {
    var kindRawValue: String
    var occurredAt: Date
    var isValidated: Bool

    init(kind: PresenceEvent.Kind, occurredAt: Date, isValidated: Bool = false) {
        self.kindRawValue = kind.rawValue
        self.occurredAt = occurredAt
        self.isValidated = isValidated
    }
}

@Model
final class AttendanceDayModel {
    @Attribute(.unique) var dayIdentifier: String
    var arrivedAt: Date?
    var leftAt: Date?
    var totalDuration: TimeInterval
    var statusRawValue: String

    init(dayIdentifier: String, arrivedAt: Date? = nil, leftAt: Date? = nil, totalDuration: TimeInterval = 0, status: AttendanceStatus = .pending) {
        self.dayIdentifier = dayIdentifier
        self.arrivedAt = arrivedAt
        self.leftAt = leftAt
        self.totalDuration = totalDuration
        self.statusRawValue = status.rawValue
    }
}

@Model
final class HolidayCalendarCacheModel {
    @Attribute(.unique) var cacheKey: String
    private(set) var year: Int
    private(set) var region: String
    var payloadJSON: String
    var sourceName: String
    var sourceUpdatedAt: Date?
    var cachedAt: Date
    var availabilityRawValue: String

    var availability: HolidayDataAvailability {
        get { HolidayDataAvailability(rawValue: availabilityRawValue) ?? .unavailable }
        set { availabilityRawValue = newValue.rawValue }
    }

    init(year: Int, region: String, payloadJSON: String, sourceName: String, sourceUpdatedAt: Date?, cachedAt: Date, availability: HolidayDataAvailability) {
        self.cacheKey = "\(region)-\(year)"
        self.year = year
        self.region = region
        self.payloadJSON = payloadJSON
        self.sourceName = sourceName
        self.sourceUpdatedAt = sourceUpdatedAt
        self.cachedAt = cachedAt
        self.availabilityRawValue = availability.rawValue
    }
}

enum HolidayDataAvailability: String, Codable, Hashable {
    case fresh
    case cached
    case unavailable
}

// MARK: - Domain conversion

extension AttendanceDayModel {
    func toAttendanceDay() -> AttendanceDay {
        AttendanceDay(
            dayIdentifier: dayIdentifier,
            arrivedAt: arrivedAt,
            leftAt: leftAt,
            totalDuration: totalDuration,
            status: AttendanceStatus(rawValue: statusRawValue) ?? .pending
        )
    }
}
