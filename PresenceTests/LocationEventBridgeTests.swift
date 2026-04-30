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

    /// Yields enough times to let the bridge's internal Task (sleep → handleCandidate → store/activity) finish.
    private func drainMainActor() async {
        for _ in 0..<8 { await Task.yield() }
    }

    // MARK: - Synchrony guard

    func testEnterDelegateDoesNotCallCoordinatorSynchronously() async {
        let store = SpyStore()
        let bridge = makeBridge(store: store, activity: SpyActivity(), clock: clockPastDebounce)

        bridge.locationMonitorDidEnterRegion(at: t0)

        XCTAssertTrue(store.savedEvents.isEmpty, "Coordinator must not be called synchronously on delegate callback")
    }

    func testExitDelegateDoesNotCallCoordinatorSynchronously() async {
        let store = SpyStore()
        let bridge = makeBridge(store: store, activity: SpyActivity(), clock: clockPastDebounce)

        bridge.locationMonitorDidExitRegion(at: t0)

        XCTAssertTrue(store.savedEvents.isEmpty, "Coordinator must not be called synchronously on delegate callback")
    }

    // MARK: - Enter event persisted after debounce

    func testEnterEventPersistedAndActivityStartedAfterDebounce() async {
        let store = SpyStore()
        let activity = SpyActivity()
        let bridge = makeBridge(store: store, activity: activity, clock: clockPastDebounce)

        bridge.locationMonitorDidEnterRegion(at: t0)
        await drainMainActor()

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
        await drainMainActor()

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
        await drainMainActor()

        XCTAssertTrue(store.savedEvents.isEmpty, "Event at exactly 600 s must remain pending")
    }
}
