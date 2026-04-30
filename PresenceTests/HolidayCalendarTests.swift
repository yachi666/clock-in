import SwiftData
import XCTest
@testable import Presence

@MainActor
final class HolidayCalendarTests: XCTestCase {
    func testPublicHolidayOverridesWeekday() throws {
        let calendar = HolidayCalendar(
            year: 2026,
            region: "CN",
            entries: [HolidayEntry(date: "2026-05-01", name: "Labor Day", type: .publicHoliday)]
        )

        XCTAssertFalse(try calendar.isWorkday("2026-05-01"))
    }

    func testTransferWorkdayOverridesWeekend() throws {
        let calendar = HolidayCalendar(
            year: 2026,
            region: "CN",
            entries: [HolidayEntry(date: "2026-05-09", name: "Make-up Workday", type: .transferWorkday)]
        )

        XCTAssertTrue(try calendar.isWorkday("2026-05-09"))
    }

    func testMissingEntryFallsBackToWeekdayRule() throws {
        let calendar = HolidayCalendar(year: 2026, region: "CN", entries: [])

        XCTAssertTrue(try calendar.isWorkday("2026-04-30"))
        XCTAssertFalse(try calendar.isWorkday("2026-05-02"))
    }

    func testDecodesPublicAPIShapeUsingDatesKey() throws {
        let json = """
        {
          "year": 2026,
          "region": "CN",
          "dates": [
            { "date": "2026-01-01", "name": "元旦", "name_cn": "元旦", "name_en": "New Year's Day", "type": "public_holiday" },
            { "date": "2026-01-04", "name": "元旦补班", "name_cn": "元旦补班", "name_en": "New Year's Day Workday", "type": "transfer_workday" }
          ]
        }
        """.data(using: .utf8)!

        let calendar = try JSONDecoder().decode(HolidayCalendar.self, from: json)

        XCTAssertEqual(calendar.year, 2026)
        XCTAssertEqual(calendar.region, "CN")
        XCTAssertEqual(calendar.entries.count, 2)
        XCTAssertFalse(try calendar.isWorkday("2026-01-01"))
        XCTAssertTrue(try calendar.isWorkday("2026-01-04"))
    }

    func testCacheUpdatesExistingYearRegionInsteadOfInsertingDuplicate() throws {
        let context = try makeInMemoryContext()
        let service = HolidayService()
        let first = HolidayCalendar(
            year: 2026,
            region: "CN",
            entries: [HolidayEntry(date: "2026-01-01", name: "元旦", type: .publicHoliday)]
        )
        let second = HolidayCalendar(
            year: 2026,
            region: "CN",
            entries: [HolidayEntry(date: "2026-01-04", name: "元旦补班", type: .transferWorkday)]
        )

        try service.cache(first, in: context, now: Date(timeIntervalSince1970: 1_000))
        try service.cache(second, in: context, now: Date(timeIntervalSince1970: 2_000))

        let caches = try context.fetch(FetchDescriptor<HolidayCalendarCacheModel>())
        XCTAssertEqual(caches.count, 1)
        XCTAssertEqual(caches[0].cacheKey, "CN-2026")
        XCTAssertEqual(caches[0].cachedAt, Date(timeIntervalSince1970: 2_000))
        XCTAssertTrue(caches[0].payloadJSON.contains("2026-01-04"))
        XCTAssertFalse(caches[0].payloadJSON.contains("2026-01-01"))
    }

    private func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema([
            WorkplaceConfigModel.self,
            RegionEventModel.self,
            AttendanceDayModel.self,
            HolidayCalendarCacheModel.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }
}
