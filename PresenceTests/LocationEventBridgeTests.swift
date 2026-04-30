import XCTest
@testable import Presence

@MainActor
final class LocationEventBridgeTests: XCTestCase {

    // MARK: - Fakes

    /// Controllable clock; @unchecked Sendable is acceptable for test-only use.
    final class FakeClock: Clock, @unchecked Sendable {
        var now: Date
        init(now: Date) { self.now = now }
    }

    @MainActor
    final class SpyStore: TrackingStore {
        var savedEvents: [PresenceEvent] = []
        func save(_ event: PresenceEvent) async throws {
            savedEvents.append(event)
        }
    }

    @MainActor
    final class SpyActivity: PresenceActivityControlling {
        var startedArrivals: [Date] = []
        var endCallCount = 0
        func start(arrivedAt: Date) async { startedArrivals.append(arrivedAt) }
        func end() async { endCallCount += 1 }
    }

    // MARK: - Helpers

    private let t0 = Date(timeIntervalSince1970: 0)

    /// Clock advanced past the debounce window so handleCandidate will validate.
    private var clockPastDebounce: FakeClock {
        FakeClock(now: t0.addingTimeInterval(601))
    }

    private func makeBridge(
        store: SpyStore,
        activity: SpyActivity,
        clock: FakeClock
    ) -> LocationEventBridge {
        let coordinator = TrackingCoordinator(store: store, activityController: activity)
        return LocationEventBridge(
            coordinator: coordinator,
            clock: clock,
            debounceInterval: 601,
            sleep: { _ in }     // no-op; clock is already advanced
        )
    }

    // MARK: - Synchrony guard

    func testEnterDelegateDoesNotCallCoordinatorSynchronously() async {
        let store = SpyStore()
        let bridge = makeBridge(store: store, activity: SpyActivity(), clock: clockPastDebounce)

        bridge.locationMonitorDidEnterRegion(at: t0)

        XCTAssertTrue(store.savedEvents.isEmpty, "Coordinator must not be called synchronously on delegate callback")
        await bridge.pendingValidationTask?.value
    }

    func testExitDelegateDoesNotCallCoordinatorSynchronously() async {
        let store = SpyStore()
        let bridge = makeBridge(store: store, activity: SpyActivity(), clock: clockPastDebounce)

        bridge.locationMonitorDidExitRegion(at: t0)

        XCTAssertTrue(store.savedEvents.isEmpty, "Coordinator must not be called synchronously on delegate callback")
        await bridge.pendingValidationTask?.value
    }

    // MARK: - Enter event persisted after debounce

    func testEnterEventPersistedAndActivityStartedAfterDebounce() async {
        let store = SpyStore()
        let activity = SpyActivity()
        let bridge = makeBridge(store: store, activity: activity, clock: clockPastDebounce)

        bridge.locationMonitorDidEnterRegion(at: t0)
        await bridge.pendingValidationTask?.value

        XCTAssertEqual(store.savedEvents, [PresenceEvent(kind: .enter, occurredAt: t0)])
        XCTAssertEqual(activity.startedArrivals, [t0])
        XCTAssertEqual(activity.endCallCount, 0)
    }

    // MARK: - Exit event persisted after debounce

    func testExitEventPersistedAndActivityEndedAfterDebounce() async {
        let store = SpyStore()
        let activity = SpyActivity()
        let bridge = makeBridge(store: store, activity: activity, clock: clockPastDebounce)

        bridge.locationMonitorDidExitRegion(at: t0)
        await bridge.pendingValidationTask?.value

        XCTAssertEqual(store.savedEvents, [PresenceEvent(kind: .exit, occurredAt: t0)])
        XCTAssertEqual(activity.endCallCount, 1)
        XCTAssertTrue(activity.startedArrivals.isEmpty)
    }

    // MARK: - Clock not yet past debounce → still pending

    func testEnterEventNotPersistedWhenClockNotPastDebounce() async {
        // Clock is only 600 s ahead — PresenceRules requires strictly > 600 s.
        let clock = FakeClock(now: t0.addingTimeInterval(600))
        let store = SpyStore()
        let bridge = makeBridge(store: store, activity: SpyActivity(), clock: clock)

        bridge.locationMonitorDidEnterRegion(at: t0)
        await bridge.pendingValidationTask?.value

        XCTAssertTrue(store.savedEvents.isEmpty, "Event at exactly 600 s must remain pending")
    }

    // MARK: - Superseding events

    /// enter then exit before the pending task runs: only the exit event must be persisted.
    func testExitSupersedingEnterPersistsOnlyExit() async {
        let store = SpyStore()
        let activity = SpyActivity()
        // Clock must be > 600 s ahead of the *latest* event (tExit = t0+5), so use t0+700.
        let clock = FakeClock(now: t0.addingTimeInterval(700))
        let bridge = makeBridge(store: store, activity: activity, clock: clock)

        let tEnter = t0
        let tExit = t0.addingTimeInterval(5)

        bridge.locationMonitorDidEnterRegion(at: tEnter)
        // Supersede with exit before the pending task runs.
        bridge.locationMonitorDidExitRegion(at: tExit)
        await bridge.pendingValidationTask?.value

        XCTAssertEqual(store.savedEvents, [PresenceEvent(kind: .exit, occurredAt: tExit)],
                       "Only the superseding exit event must be persisted")
        XCTAssertTrue(activity.startedArrivals.isEmpty,
                      "Enter activity must not start when enter task was cancelled")
        XCTAssertEqual(activity.endCallCount, 1)
    }

    /// enter → exit → re-enter: only the last enter is persisted.
    func testReenterAfterExitPersistsOnlyLatestEnter() async {
        let store = SpyStore()
        let activity = SpyActivity()
        // Clock must be > 600 s ahead of the *latest* event (tEnter1 = t0+10), so use t0+700.
        let clock = FakeClock(now: t0.addingTimeInterval(700))
        let bridge = makeBridge(store: store, activity: activity, clock: clock)

        let tEnter0 = t0
        let tExit = t0.addingTimeInterval(5)
        let tEnter1 = t0.addingTimeInterval(10)

        bridge.locationMonitorDidEnterRegion(at: tEnter0)
        bridge.locationMonitorDidExitRegion(at: tExit)
        bridge.locationMonitorDidEnterRegion(at: tEnter1)
        await bridge.pendingValidationTask?.value

        XCTAssertEqual(store.savedEvents, [PresenceEvent(kind: .enter, occurredAt: tEnter1)],
                       "Only the last enter event must be persisted after two supersessions")
        XCTAssertEqual(activity.startedArrivals, [tEnter1])
        XCTAssertEqual(activity.endCallCount, 0)
    }
}
