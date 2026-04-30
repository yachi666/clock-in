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

    func testUnknownAPITypeDoesNotFailWholeCalendarDecode() throws {
        let json = """
        {
          "year": 2026,
          "region": "CN",
          "dates": [
            { "date": "2026-01-01", "name": "元旦", "type": "public_holiday" },
            { "date": "2026-01-02", "name": "未来类型", "type": "future_type" }
          ]
        }
        """.data(using: .utf8)!

        let calendar = try JSONDecoder().decode(HolidayCalendar.self, from: json)

        XCTAssertEqual(calendar.entries.count, 2)
        XCTAssertEqual(calendar.entries[1].type, .unknown)
        XCTAssertTrue(try calendar.isWorkday("2026-01-02"))
    }

    func testFetchCalendarDecodesSuccessfulResponse() async throws {
        let json = """
        {
          "year": 2026,
          "region": "CN",
          "dates": [
            { "date": "2026-01-01", "name": "元旦", "type": "public_holiday" }
          ]
        }
        """.data(using: .utf8)!
        let service = HolidayService(session: makeStubSession(data: json, statusCode: 200))

        let calendar = try await service.fetchCalendar(year: 2026)

        XCTAssertEqual(calendar.year, 2026)
        XCTAssertEqual(calendar.region, "CN")
        XCTAssertEqual(calendar.entries.count, 1)
    }

    func testFetchCalendarThrowsOnHTTP404() async {
        let service = HolidayService(session: makeStubSession(data: Data(), statusCode: 404))

        do {
            _ = try await service.fetchCalendar(year: 2026)
            XCTFail("Expected fetchCalendar to throw for a 404 response")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .badServerResponse)
        } catch {
            XCTFail("Expected URLError.badServerResponse, got \(error)")
        }
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
        XCTAssertEqual(caches[0].availability, .fresh)
        XCTAssertEqual(caches[0].cachedAt, Date(timeIntervalSince1970: 2_000))
        XCTAssertTrue(caches[0].payloadJSON.contains("2026-01-04"))
        XCTAssertFalse(caches[0].payloadJSON.contains("2026-01-01"))
    }

    func testUnknownCachedAvailabilityDefaultsToUnavailable() throws {
        let model = HolidayCalendarCacheModel(
            year: 2026,
            region: "CN",
            payloadJSON: "{}",
            sourceName: "holiday-calendar",
            sourceUpdatedAt: nil,
            cachedAt: Date(timeIntervalSince1970: 1_000),
            availability: .fresh
        )

        model.availabilityRawValue = "future_value"

        XCTAssertEqual(model.availability, .unavailable)
    }

    func testLoadCachedCalendarReturnsStoredCalendarAndMarksItCached() throws {
        let context = try makeInMemoryContext()
        let service = HolidayService()
        let calendar = HolidayCalendar(
            year: 2026,
            region: "CN",
            entries: [HolidayEntry(date: "2026-01-01", name: "元旦", type: .publicHoliday)]
        )
        try service.cache(calendar, in: context, now: Date(timeIntervalSince1970: 1_000))

        let loaded = try service.loadCachedCalendar(year: 2026, region: "CN", in: context)

        XCTAssertEqual(loaded, calendar)
        let caches = try context.fetch(FetchDescriptor<HolidayCalendarCacheModel>())
        XCTAssertEqual(caches[0].availability, .cached)
    }

    func testLoadCachedCalendarReturnsNilForUnavailableCache() throws {
        let context = try makeInMemoryContext()
        context.insert(HolidayCalendarCacheModel(
            year: 2026,
            region: "CN",
            payloadJSON: "{}",
            sourceName: "holiday-calendar",
            sourceUpdatedAt: nil,
            cachedAt: Date(timeIntervalSince1970: 1_000),
            availability: .unavailable
        ))
        try context.save()

        let loaded = try HolidayService().loadCachedCalendar(year: 2026, region: "CN", in: context)

        XCTAssertNil(loaded)
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

    private func makeStubSession(data: Data, statusCode: Int) -> URLSession {
        URLProtocolStub.setResponse(data: data, statusCode: statusCode)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: configuration)
    }
}

private final class URLProtocolStub: URLProtocol {
    private static let lock = NSLock()
    private nonisolated(unsafe) static var responseData = Data()
    private nonisolated(unsafe) static var statusCode = 200

    static func setResponse(data: Data, statusCode: Int) {
        lock.withLock {
            responseData = data
            self.statusCode = statusCode
        }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let stubbedResponse = Self.lock.withLock {
            (data: Self.responseData, statusCode: Self.statusCode)
        }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: stubbedResponse.statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stubbedResponse.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
