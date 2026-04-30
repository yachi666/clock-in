import SwiftData
import XCTest
@testable import Presence

@MainActor
final class DashboardLoadCoordinatorTests: XCTestCase {

    // MARK: - Helpers

    private func makeContext() throws -> ModelContext {
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

    private func makeCoordinator(
        context: ModelContext,
        session: URLSession = makeStubSession(data: Data(), statusCode: 500)
    ) -> DashboardLoadCoordinator {
        DashboardLoadCoordinator(
            store: AttendanceStore(context: context),
            holidayService: HolidayService(session: session),
            context: context
        )
    }

    private static func makeStubSession(data: Data, statusCode: Int) -> URLSession {
        DashboardURLProtocolStub.setResponse(data: data, statusCode: statusCode)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [DashboardURLProtocolStub.self]
        return URLSession(configuration: config)
    }

    private static let validCalendarJSON: Data = {
        """
        {
          "year": 2026,
          "region": "CN",
          "dates": [
            { "date": "2026-05-01", "name": "劳动节", "type": "public_holiday" }
          ]
        }
        """.data(using: .utf8)!
    }()

    // MARK: - Tests

    func testCacheHitReturnsSummaryWithoutFetch() async throws {
        let context = try makeContext()
        let service = HolidayService()
        let calendar = HolidayCalendar(year: 2026, region: "CN", entries: [
            HolidayEntry(date: "2026-05-01", name: "劳动节", type: .publicHoliday)
        ])
        try service.cache(calendar, in: context)

        // Use a session that would fail if called.
        let coordinator = makeCoordinator(context: context)
        let result = await coordinator.load(monthIdentifier: "2026-05")

        if case .loaded(let summary, _) = result {
            XCTAssertEqual(summary.monthIdentifier, "2026-05")
            // 2026-05: 31 days, May 1 is holiday, weekend days = 4*2=8 → 31-8-1=22
            XCTAssertGreaterThan(summary.workingDays, 0)
        } else {
            XCTFail("Expected .loaded but got \(result)")
        }
    }

    func testCacheMissThenFetchSuccessReturnsLoadedAndCachesCalendar() async throws {
        let context = try makeContext()
        let session = Self.makeStubSession(data: Self.validCalendarJSON, statusCode: 200)
        let coordinator = makeCoordinator(context: context, session: session)

        let result = await coordinator.load(monthIdentifier: "2026-05")

        // Result should be loaded.
        if case .loaded(let summary, _) = result {
            XCTAssertEqual(summary.monthIdentifier, "2026-05")
        } else {
            XCTFail("Expected .loaded but got \(result)")
        }

        // Calendar should now be cached.
        let cached = try HolidayService().loadCachedCalendar(year: 2026, region: "CN", in: context)
        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.year, 2026)
    }

    func testCacheMissThenFetchFailureReturnsHolidayUnavailable() async throws {
        let context = try makeContext()
        // Session returns 500 → fetch throws.
        let coordinator = makeCoordinator(context: context)

        let result = await coordinator.load(monthIdentifier: "2026-05")

        if case .holidayUnavailable(_, _, let monthId) = result {
            XCTAssertEqual(monthId, "2026-05")
        } else {
            XCTFail("Expected .holidayUnavailable but got \(result)")
        }
    }

    func testUnavailableCacheThenFetchFailureReturnsUnavailable() async throws {
        let context = try makeContext()
        // Insert a cache entry marked unavailable.
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

        let coordinator = makeCoordinator(context: context)
        let result = await coordinator.load(monthIdentifier: "2026-05")

        if case .holidayUnavailable = result {
            // expected
        } else {
            XCTFail("Expected .holidayUnavailable but got \(result)")
        }
    }

    func testAttendanceDaysAreIncludedInResult() async throws {
        let context = try makeContext()
        let store = AttendanceStore(context: context)
        let presentDay = AttendanceDay(
            dayIdentifier: "2026-05-06",
            arrivedAt: Date(timeIntervalSince1970: 1_746_504_000),
            leftAt: Date(timeIntervalSince1970: 1_746_504_000 + 32400),
            totalDuration: 32400,
            status: .present
        )
        try store.upsertAttendanceDay(presentDay)

        // Cache hit path.
        let calendar = HolidayCalendar(year: 2026, region: "CN", entries: [])
        try HolidayService().cache(calendar, in: context)

        let coordinator = DashboardLoadCoordinator(
            store: store,
            holidayService: HolidayService(),
            context: context
        )
        let result = await coordinator.load(monthIdentifier: "2026-05")

        if case .loaded(let summary, let days) = result {
            XCTAssertEqual(summary.presentDays, 1)
            XCTAssertEqual(days.count, 1)
            XCTAssertEqual(days.first?.dayIdentifier, "2026-05-06")
        } else {
            XCTFail("Expected .loaded but got \(result)")
        }
    }

    func testInvalidMonthIdentifierReturnsUnavailable() async throws {
        let context = try makeContext()
        let coordinator = makeCoordinator(context: context)

        let result = await coordinator.load(monthIdentifier: "invalid")

        if case .holidayUnavailable(let presentDays, let days, _) = result {
            XCTAssertEqual(presentDays, 0)
            XCTAssertTrue(days.isEmpty)
        } else {
            XCTFail("Expected .holidayUnavailable but got \(result)")
        }
    }
}

// MARK: - URL stub

private final class DashboardURLProtocolStub: URLProtocol {
    private static let lock = NSLock()
    private nonisolated(unsafe) static var responseData = Data()
    private nonisolated(unsafe) static var statusCode = 200

    static func setResponse(data: Data, statusCode: Int) {
        lock.withLock {
            responseData = data
            self.statusCode = statusCode
        }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let (data, code) = Self.lock.withLock { (Self.responseData, Self.statusCode) }
        let response = HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
