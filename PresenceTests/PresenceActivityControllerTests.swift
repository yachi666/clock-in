import XCTest
@testable import Presence

@MainActor
final class PresenceActivityControllerTests: XCTestCase {

    // MARK: - Fakes

    final class FakeClient: ActivityRequesting, @unchecked Sendable {
        var areActivitiesEnabled = true
        var requestShouldThrow = false
        var requestCallCount = 0
        private(set) var lastCreatedHandle: FakeHandle?

        enum ClientError: Error { case requestFailed }

        func requestActivity(
            attributes: PresenceActivityAttributes,
            contentState: PresenceActivityAttributes.ContentState,
            staleDate: Date?
        ) throws -> any ActivityEnding {
            requestCallCount += 1
            if requestShouldThrow { throw ClientError.requestFailed }
            let handle = FakeHandle(initialState: contentState)
            lastCreatedHandle = handle
            return handle
        }
    }

    final class FakeHandle: ActivityEnding, @unchecked Sendable {
        private(set) var endCallCount = 0
        private(set) var lastEndedState: PresenceActivityAttributes.ContentState?
        let initialState: PresenceActivityAttributes.ContentState

        init(initialState: PresenceActivityAttributes.ContentState) {
            self.initialState = initialState
        }

        @MainActor func end(contentState: PresenceActivityAttributes.ContentState) async {
            endCallCount += 1
            lastEndedState = contentState
        }
    }

    struct FixedClock: Clock {
        let now: Date
    }

    // MARK: - Helpers

    private let t0 = Date(timeIntervalSince1970: 0)

    private func makeSUT(
        client: FakeClient = FakeClient(),
        now: Date = Date(timeIntervalSince1970: 100)
    ) -> (PresenceActivityController, FakeClient) {
        let sut = PresenceActivityController(client: client, clock: FixedClock(now: now))
        return (sut, client)
    }

    // MARK: - start: activities disabled

    func testStartWhenActivitiesDisabledDoesNotRequest() async {
        let client = FakeClient()
        client.areActivitiesEnabled = false
        let (sut, _) = makeSUT(client: client)

        await sut.start(arrivedAt: t0)

        XCTAssertEqual(client.requestCallCount, 0)
    }

    // MARK: - start: duplicate prevention

    func testStartWhenAlreadyActiveDoesNotRequestAgain() async {
        let (sut, client) = makeSUT()

        await sut.start(arrivedAt: t0)
        await sut.start(arrivedAt: t0)

        XCTAssertEqual(client.requestCallCount, 1)
    }

    // MARK: - start: request failure

    func testStartRequestFailureDoesNotStoreActivity() async {
        let client = FakeClient()
        client.requestShouldThrow = true
        let (sut, _) = makeSUT(client: client)

        // Must not crash
        await sut.start(arrivedAt: t0)

        // After failure, a second start should try again (no duplicate guard triggered)
        client.requestShouldThrow = false
        await sut.start(arrivedAt: t0)
        XCTAssertEqual(client.requestCallCount, 2, "Failed request must not block a subsequent attempt")
    }

    // MARK: - start: happy path

    func testStartSuccessBuildsCorrectContentState() async {
        let arrivedAt = Date(timeIntervalSince1970: 0)
        let now = Date(timeIntervalSince1970: 30)
        let client = FakeClient()
        let sut = PresenceActivityController(client: client, clock: FixedClock(now: now))

        await sut.start(arrivedAt: arrivedAt)

        XCTAssertEqual(client.requestCallCount, 1)
        XCTAssertEqual(client.lastCreatedHandle?.initialState.arrivedAt, arrivedAt)
        XCTAssertEqual(client.lastCreatedHandle?.initialState.elapsedSeconds ?? -1, 30, accuracy: 0.001)
    }

    func testStartPassesElapsedSecondsToContentState() async {
        let arrivedAt = Date(timeIntervalSince1970: 0)
        let now = Date(timeIntervalSince1970: 60)
        var capturedState: PresenceActivityAttributes.ContentState?

        final class CapturingClient: ActivityRequesting, @unchecked Sendable {
            var areActivitiesEnabled = true
            var captured: PresenceActivityAttributes.ContentState?
            func requestActivity(
                attributes: PresenceActivityAttributes,
                contentState: PresenceActivityAttributes.ContentState,
                staleDate: Date?
            ) throws -> any ActivityEnding {
                captured = contentState
                return FakeHandle(initialState: contentState)
            }
        }

        let client = CapturingClient()
        let sut = PresenceActivityController(client: client, clock: FixedClock(now: now))
        await sut.start(arrivedAt: arrivedAt)
        capturedState = client.captured

        XCTAssertEqual(capturedState?.arrivedAt, arrivedAt)
        XCTAssertEqual(capturedState?.elapsedSeconds ?? -1, 60, accuracy: 0.001)
    }

    func testStartClampsNegativeElapsedToZero() async {
        let arrivedAt = Date(timeIntervalSince1970: 100)
        let now = Date(timeIntervalSince1970: 50)  // clock is before arrivedAt

        final class CapturingClient: ActivityRequesting, @unchecked Sendable {
            var areActivitiesEnabled = true
            var captured: PresenceActivityAttributes.ContentState?
            func requestActivity(
                attributes: PresenceActivityAttributes,
                contentState: PresenceActivityAttributes.ContentState,
                staleDate: Date?
            ) throws -> any ActivityEnding {
                captured = contentState
                return FakeHandle(initialState: contentState)
            }
        }

        let client = CapturingClient()
        let sut = PresenceActivityController(client: client, clock: FixedClock(now: now))
        await sut.start(arrivedAt: arrivedAt)

        XCTAssertEqual(client.captured?.elapsedSeconds, 0)
    }

    // MARK: - end: no active activity

    func testEndWithNoActivityIsNoOp() async {
        let (sut, _) = makeSUT()
        // Must not crash
        await sut.end()
    }

    // MARK: - end: clears activity

    func testEndCallsThroughAndClearsActivity() async {
        let client = FakeClient()
        let (sut, _) = makeSUT(client: client)

        await sut.start(arrivedAt: t0)
        let handle = client.lastCreatedHandle

        await sut.end()

        XCTAssertEqual(handle?.endCallCount, 1, "end(contentState:) must be called exactly once")
        let expectedState = PresenceActivityAttributes.ContentState(
            arrivedAt: t0,
            elapsedSeconds: 100  // makeSUT uses now = timeIntervalSince1970: 100, t0 = 0
        )
        XCTAssertEqual(handle?.lastEndedState, expectedState, "Must end with the state that was set on start")

        // After end, currentActivity is nil — a new start must be allowed
        await sut.start(arrivedAt: t0)
        XCTAssertEqual(client.requestCallCount, 2, "Activity should be clearable so a new one can start")
    }
}
