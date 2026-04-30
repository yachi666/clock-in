import Foundation
import OSLog

/// Bridges LocationMonitor delegate events into TrackingCoordinator.
///
/// On each region transition, a Task is scheduled that sleeps for `debounceInterval`
/// seconds (> 600 s by default to satisfy PresenceRules' strict > 10-minute window)
/// before forwarding the event to the coordinator. The `sleep` dependency is
/// injectable so tests can replace it with a no-op and advance a fake clock.
@MainActor
final class LocationEventBridge: LocationMonitorDelegate {
    private let coordinator: TrackingCoordinator
    private let clock: any Clock
    private let debounceInterval: TimeInterval
    private let sleep: (TimeInterval) async throws -> Void
    private let logger = Logger(subsystem: "com.presence.app", category: "Tracking")

    init(
        coordinator: TrackingCoordinator,
        clock: any Clock = SystemClock(),
        debounceInterval: TimeInterval = 601,
        sleep: @escaping (TimeInterval) async throws -> Void = { interval in
            try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }
    ) {
        self.coordinator = coordinator
        self.clock = clock
        self.debounceInterval = debounceInterval
        self.sleep = sleep
    }

    func locationMonitorDidEnterRegion(at date: Date) {
        let event = PresenceEvent(kind: .enter, occurredAt: date)
        Task {
            do {
                try await sleep(debounceInterval)
                try await coordinator.handleCandidate(event, validationDate: clock.now)
            } catch {
                logger.error("TrackingCoordinator enter failed: \(error, privacy: .public)")
            }
        }
    }

    func locationMonitorDidExitRegion(at date: Date) {
        let event = PresenceEvent(kind: .exit, occurredAt: date)
        Task {
            do {
                try await sleep(debounceInterval)
                try await coordinator.handleCandidate(event, validationDate: clock.now)
            } catch {
                logger.error("TrackingCoordinator exit failed: \(error, privacy: .public)")
            }
        }
    }

    func locationMonitorDidFail(with error: Error) {
        logger.error("LocationMonitor failed: \(error, privacy: .public)")
    }
}
