import Foundation
import SwiftData

@MainActor
final class AttendanceStore {
    private let context: ModelContext
    private let rules: PresenceRules

    init(context: ModelContext, rules: PresenceRules = PresenceRules()) {
        self.context = context
        self.rules = rules
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

// MARK: - TrackingStore conformance

extension AttendanceStore: TrackingStore {
    func save(_ event: PresenceEvent) async throws {
        switch event.kind {
        case .enter: try saveValidatedEnter(event)
        case .exit:  try saveValidatedExit(event)
        }
    }

    private func saveValidatedEnter(_ event: PresenceEvent) throws {
        context.insert(RegionEventModel(kind: event.kind, occurredAt: event.occurredAt, isValidated: true))

        let id = dayIdentifier(for: event.occurredAt, calendar: rules.calendar)
        var descriptor = FetchDescriptor<AttendanceDayModel>(
            predicate: #Predicate { $0.dayIdentifier == id }
        )
        descriptor.fetchLimit = 1
        let existing = try context.fetch(descriptor).first

        if let existing {
            // Preserve a day that is already present; do not regress it to pending.
            guard existing.statusRawValue != AttendanceStatus.present.rawValue else {
                try context.save()
                return
            }
            // Pending: keep the earliest known arrival.
            if existing.arrivedAt == nil || existing.arrivedAt! > event.occurredAt {
                existing.arrivedAt = event.occurredAt
            }
        } else {
            context.insert(AttendanceDayModel(dayIdentifier: id, arrivedAt: event.occurredAt, status: .pending))
        }

        try context.save()
    }

    private func saveValidatedExit(_ event: PresenceEvent) throws {
        context.insert(RegionEventModel(kind: event.kind, occurredAt: event.occurredAt, isValidated: true))

        // Find the latest validated enter at or before this exit.
        let exitTime = event.occurredAt
        let enterKind = PresenceEvent.Kind.enter.rawValue
        var enterDescriptor = FetchDescriptor<RegionEventModel>(
            predicate: #Predicate {
                $0.kindRawValue == enterKind && $0.isValidated == true && $0.occurredAt <= exitTime
            },
            sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
        )
        enterDescriptor.fetchLimit = 1
        let latestEnter = try context.fetch(enterDescriptor).first

        guard let enterOccurredAt = latestEnter?.occurredAt else {
            // No validated enter found; persist the exit event only.
            try context.save()
            return
        }

        let dayId = rules.attendanceDayIdentifier(forExitAt: exitTime)
        var dayDescriptor = FetchDescriptor<AttendanceDayModel>(
            predicate: #Predicate { $0.dayIdentifier == dayId }
        )
        dayDescriptor.fetchLimit = 1
        let existingDay = try context.fetch(dayDescriptor).first

        // Use the earliest known arrival for this day.
        let effectiveArrival: Date
        if let existingArrival = existingDay?.arrivedAt, existingArrival < enterOccurredAt {
            effectiveArrival = existingArrival
        } else {
            effectiveArrival = enterOccurredAt
        }

        let day = rules.buildAttendanceDay(arrivedAt: effectiveArrival, leftAt: exitTime)
        guard day.status == .present else {
            try context.save()
            return
        }

        let model: AttendanceDayModel
        if let existingDay {
            model = existingDay
        } else {
            let newModel = AttendanceDayModel(dayIdentifier: dayId)
            context.insert(newModel)
            model = newModel
        }
        model.arrivedAt = day.arrivedAt
        model.leftAt = day.leftAt
        model.totalDuration = day.totalDuration
        model.statusRawValue = day.status.rawValue

        try context.save()
    }
}
