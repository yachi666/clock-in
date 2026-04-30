import Foundation
import OSLog

/// Bridges LocationMonitor delegate events into TrackingCoordinator.
///
/// Each region transition cancels any previous pending validation task and schedules
/// a new one that sleeps for `debounceInterval` seconds (> 600 s by default to satisfy
/// PresenceRules' strict > 10-minute window) before forwarding the event to the
/// coordinator. Only the most-recent event is ever persisted. The `sleep` dependency is
/// injectable so tests can replace it with a no-op and advance a fake clock.
@MainActor
final class LocationEventBridge: LocationMonitorDelegate {
    private let coordinator: TrackingCoordinator
    private let clock: any Clock
    private let debounceInterval: TimeInterval
    private let sleep: (TimeInterval) async throws -> Void
    private let logger = Logger(subsystem: "com.presence.app", category: "Tracking")

    /// The single in-flight validation task. Exposed internally so `@testable` tests
    /// can `await bridge.pendingValidationTask?.value` for deterministic synchronisation.
    private(set) var pendingValidationTask: Task<Void, Never>?

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
        scheduleValidation(for: PresenceEvent(kind: .enter, occurredAt: date))
    }

    func locationMonitorDidExitRegion(at date: Date) {
        scheduleValidation(for: PresenceEvent(kind: .exit, occurredAt: date))
    }

    func locationMonitorDidFail(with error: Error) {
        logger.error("LocationMonitor failed: \(error, privacy: .public)")
    }

    // MARK: - Private

    private func scheduleValidation(for event: PresenceEvent) {
        pendingValidationTask?.cancel()
        pendingValidationTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.sleep(self.debounceInterval)
                try Task.checkCancellation()
                try await self.coordinator.handleCandidate(event, validationDate: self.clock.now)
            } catch is CancellationError {
                // Superseded by a newer event — normal operation, not a tracking failure.
            } catch {
                self.logger.error("TrackingCoordinator validation failed: \(error, privacy: .public)")
            }
        }
    }
}
