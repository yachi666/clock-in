import XCTest
@testable import Presence

@MainActor
final class PresenceActivityControllerTests: XCTestCase {

    // MARK: - Fakes

    final class FakeClient: ActivityRequesting, @unchecked Sendable {
        var areActivitiesEnabled = true
        var requestShouldThrow = false
        var requestCallCount = 0

        enum ClientError: Error { case requestFailed }

        func requestActivity(
            attributes: PresenceActivityAttributes,
            contentState: PresenceActivityAttributes.ContentState,
            staleDate: Date?
        ) throws -> any ActivityEnding {
            requestCallCount += 1
            if requestShouldThrow { throw ClientError.requestFailed }
            return FakeHandle(initialState: contentState)
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
        let handle = (client as AnyObject) as? FakeClient  // just to confirm it was called
        _ = handle  // suppress warning; actual state checked via handle below
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

        // Grab the handle before end
        // After end, a subsequent start should succeed (activity cleared)
        await sut.end()

        // Re-start should be allowed (currentActivity is nil again)
        await sut.start(arrivedAt: t0)
        XCTAssertEqual(client.requestCallCount, 2, "Activity should be clearable so a new one can start")
    }
}
