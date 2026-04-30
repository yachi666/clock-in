import Foundation
import OSLog

/// Bridges LocationMonitor delegate events into TrackingCoordinator.
@MainActor
final class LocationEventBridge: LocationMonitorDelegate {
    private let coordinator: TrackingCoordinator
    private let clock: any Clock
    private let logger = Logger(subsystem: "com.presence.app", category: "Tracking")

    init(coordinator: TrackingCoordinator, clock: any Clock = SystemClock()) {
        self.coordinator = coordinator
        self.clock = clock
    }

    func locationMonitorDidEnterRegion(at date: Date) {
        let event = PresenceEvent(kind: .enter, occurredAt: date)
        let validationDate = clock.now
        Task {
            do {
                try await coordinator.handleCandidate(event, validationDate: validationDate)
            } catch {
                logger.error("TrackingCoordinator enter failed: \(error, privacy: .public)")
            }
        }
    }

    func locationMonitorDidExitRegion(at date: Date) {
        let event = PresenceEvent(kind: .exit, occurredAt: date)
        let validationDate = clock.now
        Task {
            do {
                try await coordinator.handleCandidate(event, validationDate: validationDate)
            } catch {
                logger.error("TrackingCoordinator exit failed: \(error, privacy: .public)")
            }
        }
    }

    func locationMonitorDidFail(with error: Error) {
        logger.error("LocationMonitor failed: \(error, privacy: .public)")
    }
}
