import Foundation
import SwiftData

@MainActor
final class AttendanceStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func saveWorkplace(latitude: Double, longitude: Double, radiusMeters: Double, now: Date = Date()) throws {
        let key = "workplace"
        var descriptor = FetchDescriptor<WorkplaceConfigModel>(
            predicate: #Predicate { $0.singletonKey == key }
        )
        descriptor.fetchLimit = 1
        let existing = try context.fetch(descriptor).first

        if let existing {
            existing.latitude = latitude
            existing.longitude = longitude
            existing.radiusMeters = radiusMeters
            existing.completedSetup = true
            existing.updatedAt = now
        } else {
            context.insert(WorkplaceConfigModel(latitude: latitude, longitude: longitude, radiusMeters: radiusMeters, createdAt: now, updatedAt: now))
        }

        try context.save()
    }

    func fetchWorkplace() throws -> WorkplaceConfigModel? {
        let key = "workplace"
        var descriptor = FetchDescriptor<WorkplaceConfigModel>(
            predicate: #Predicate { $0.singletonKey == key }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func saveRegionEvent(_ event: PresenceEvent, isValidated: Bool) throws {
        context.insert(RegionEventModel(kind: event.kind, occurredAt: event.occurredAt, isValidated: isValidated))
        try context.save()
    }

    func upsertAttendanceDay(_ day: AttendanceDay) throws {
        let id = day.dayIdentifier
        var descriptor = FetchDescriptor<AttendanceDayModel>(
            predicate: #Predicate { $0.dayIdentifier == id }
        )
        descriptor.fetchLimit = 1

        let model = try context.fetch(descriptor).first ?? AttendanceDayModel(dayIdentifier: day.dayIdentifier)
        model.arrivedAt = day.arrivedAt
        model.leftAt = day.leftAt
        model.totalDuration = day.totalDuration
        model.statusRawValue = day.status.rawValue

        if model.modelContext == nil {
            context.insert(model)
        }

        try context.save()
    }

    func fetchAttendanceDays(inMonth month: Date, calendar: Calendar = .current) throws -> [AttendanceDayModel] {
        guard let interval = calendar.dateInterval(of: .month, for: month) else {
            throw AttendanceStoreError.invalidMonth(month)
        }
        let start = dayIdentifier(for: interval.start, calendar: calendar)
        let end = dayIdentifier(for: interval.end.addingTimeInterval(-1), calendar: calendar)
        let descriptor = FetchDescriptor<AttendanceDayModel>(
            predicate: #Predicate { $0.dayIdentifier >= start && $0.dayIdentifier <= end },
            sortBy: [SortDescriptor(\.dayIdentifier)]
        )
        return try context.fetch(descriptor)
    }
}

enum AttendanceStoreError: Error, Equatable {
    case invalidMonth(Date)
}
