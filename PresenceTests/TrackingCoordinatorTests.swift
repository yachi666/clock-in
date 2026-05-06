import XCTest
@testable import Presence

@MainActor
final class TrackingCoordinatorTests: XCTestCase {

    // MARK: - Fakes

    @MainActor
    final class FakeTrackingStore: TrackingStore {
        var candidateEvents: [PresenceEvent] = []
        var savedEvents: [PresenceEvent] = []
        var pendingEvents: [PresenceEvent] = []
        var shouldThrow = false

        enum StoreError: Error { case failed }

        func saveCandidate(_ event: PresenceEvent) async throws {
            if shouldThrow { throw StoreError.failed }
            candidateEvents.append(event)
        }

        func pendingCandidates(eligibleAt date: Date) async throws -> [PresenceEvent] {
            if shouldThrow { throw StoreError.failed }
            return pendingEvents
        }

        func save(_ event: PresenceEvent) async throws {
            if shouldThrow { throw StoreError.failed }
            savedEvents.append(event)
        }
    }

    @MainActor
    final class FakeActivityController: PresenceActivityControlling {
        var startedArrivals: [Date] = []
        var endCallCount = 0

        func start(arrivedAt: Date) async {
            startedArrivals.append(arrivedAt)
        }

        func end() async {
            endCallCount += 1
        }
    }

    // MARK: - Helpers

    private let t0 = Date(timeIntervalSince1970: 0)

    private func makeSUT(
        store: FakeTrackingStore = FakeTrackingStore(),
        activity: FakeActivityController = FakeActivityController()
    ) -> (TrackingCoordinator, FakeTrackingStore, FakeActivityController) {
        (TrackingCoordinator(store: store, activityController: activity), store, activity)
    }

    // MARK: - Pending (sub-10-minute and exactly 600 s = not yet validated)

    func testRecordCandidatePersistsRawEventWithoutActivitySideEffects() async throws {
        let (sut, store, activity) = makeSUT()
        let event = PresenceEvent(kind: .enter, occurredAt: t0)

        try await sut.recordCandidate(event)

        XCTAssertEqual(store.candidateEvents, [event])
        XCTAssertTrue(store.savedEvents.isEmpty)
        XCTAssertTrue(activity.startedArrivals.isEmpty)
        XCTAssertEqual(activity.endCallCount, 0)
    }

    func testProcessPendingCandidatesValidatesRecoveredEvents() async throws {
        let store = FakeTrackingStore()
        let activity = FakeActivityController()
        let sut = TrackingCoordinator(store: store, activityController: activity)
        let event = PresenceEvent(kind: .enter, occurredAt: t0)
        store.pendingEvents = [event]

        try await sut.processPendingCandidates(validationDate: t0.addingTimeInterval(601))

        XCTAssertEqual(store.savedEvents, [event])
        XCTAssertEqual(activity.startedArrivals, [t0])
        XCTAssertEqual(activity.endCallCount, 0)
    }

    func testPendingBeforeDebounceWindowDoesNotPersistOrTouchActivity() async throws {
        let (sut, store, activity) = makeSUT()
        let event = PresenceEvent(kind: .enter, occurredAt: t0)

        try await sut.handleCandidate(event, validationDate: t0.addingTimeInterval(599))

        XCTAssertTrue(store.savedEvents.isEmpty)
        XCTAssertTrue(activity.startedArrivals.isEmpty)
        XCTAssertEqual(activity.endCallCount, 0)
    }

    func testPendingAtExactly600sDoesNotPersistOrTouchActivity() async throws {
        let (sut, store, activity) = makeSUT()
        let event = PresenceEvent(kind: .enter, occurredAt: t0)

        try await sut.handleCandidate(event, validationDate: t0.addingTimeInterval(600))

        XCTAssertTrue(store.savedEvents.isEmpty)
        XCTAssertTrue(activity.startedArrivals.isEmpty)
        XCTAssertEqual(activity.endCallCount, 0)
    }

    // MARK: - Validated enter

    func testValidatedEnterPersistsAndStartsActivity() async throws {
        let (sut, store, activity) = makeSUT()
        let event = PresenceEvent(kind: .enter, occurredAt: t0)

        try await sut.handleCandidate(event, validationDate: t0.addingTimeInterval(601))

        XCTAssertEqual(store.savedEvents, [event])
        XCTAssertEqual(activity.startedArrivals, [t0])
        XCTAssertEqual(activity.endCallCount, 0)
    }

    // MARK: - Validated exit

    func testValidatedExitPersistsAndEndsActivity() async throws {
        let (sut, store, activity) = makeSUT()
        let event = PresenceEvent(kind: .exit, occurredAt: t0)

        try await sut.handleCandidate(event, validationDate: t0.addingTimeInterval(601))

        XCTAssertEqual(store.savedEvents, [event])
        XCTAssertEqual(activity.endCallCount, 1)
        XCTAssertTrue(activity.startedArrivals.isEmpty)
    }

    // MARK: - Store errors propagate

    func testStoreErrorPropagatesAndDoesNotStartActivity() async throws {
        let store = FakeTrackingStore()
        store.shouldThrow = true
        let activity = FakeActivityController()
        let sut = TrackingCoordinator(store: store, activityController: activity)
        let event = PresenceEvent(kind: .enter, occurredAt: t0)

        do {
            try await sut.handleCandidate(event, validationDate: t0.addingTimeInterval(601))
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(activity.startedArrivals.isEmpty, "Activity must not start when store fails")
        }
    }

    func testStoreErrorPropagatesAndDoesNotEndActivity() async throws {
        let store = FakeTrackingStore()
        store.shouldThrow = true
        let activity = FakeActivityController()
        let sut = TrackingCoordinator(store: store, activityController: activity)
        let event = PresenceEvent(kind: .exit, occurredAt: t0)

        do {
            try await sut.handleCandidate(event, validationDate: t0.addingTimeInterval(601))
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(activity.endCallCount, 0, "Activity must not end when store fails")
        }
    }
}
