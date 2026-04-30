import Foundation
import SwiftData

struct HolidayService {
    var session: URLSession = .shared
    var decoder: JSONDecoder = JSONDecoder()

    func fetchCalendar(year: Int, region: String = "CN") async throws -> HolidayCalendar {
        let url = URL(string: "https://unpkg.com/holiday-calendar/data/\(region)/\(year).json")!
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try decoder.decode(HolidayCalendar.self, from: data)
    }

    @MainActor
    func cache(_ calendar: HolidayCalendar, in context: ModelContext, now: Date = Date()) throws {
        let payload = String(data: try JSONEncoder().encode(calendar), encoding: .utf8)!
        let cacheKey = "\(calendar.region)-\(calendar.year)"
        var descriptor = FetchDescriptor<HolidayCalendarCacheModel>(
            predicate: #Predicate { $0.cacheKey == cacheKey }
        )
        descriptor.fetchLimit = 1

        let model = try context.fetch(descriptor).first ?? HolidayCalendarCacheModel(
            year: calendar.year,
            region: calendar.region,
            payloadJSON: payload,
            sourceName: "holiday-calendar",
            sourceUpdatedAt: nil,
            cachedAt: now,
            availability: .fresh
        )
        model.payloadJSON = payload
        model.sourceName = "holiday-calendar"
        model.sourceUpdatedAt = nil
        model.cachedAt = now
        model.availabilityRawValue = HolidayDataAvailability.fresh.rawValue

        if model.modelContext == nil {
            context.insert(model)
        }

        try context.save()
    }

    @MainActor
    func loadCachedCalendar(year: Int, region: String = "CN", in context: ModelContext) throws -> HolidayCalendar? {
        let cacheKey = "\(region)-\(year)"
        var descriptor = FetchDescriptor<HolidayCalendarCacheModel>(
            predicate: #Predicate { $0.cacheKey == cacheKey }
        )
        descriptor.fetchLimit = 1

        guard let model = try context.fetch(descriptor).first,
              model.availability != .unavailable,
              let data = model.payloadJSON.data(using: .utf8) else {
            return nil
        }

        let calendar = try JSONDecoder().decode(HolidayCalendar.self, from: data)
        if model.availability != .cached {
            model.availability = .cached
            try context.save()
        }
        return calendar
    }
}
