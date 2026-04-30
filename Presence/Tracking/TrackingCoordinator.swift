import Foundation

protocol TrackingStore: Sendable {
    func save(_ event: PresenceEvent) async throws
}

protocol PresenceActivityControlling: AnyObject, Sendable {
    func start(arrivedAt: Date) async
    func end() async
}

final class TrackingCoordinator: Sendable {
    private let rules: PresenceRules
    private let store: any TrackingStore
    private let activityController: any PresenceActivityControlling

    init(
        rules: PresenceRules = .init(),
        store: any TrackingStore,
        activityController: any PresenceActivityControlling
    ) {
        self.rules = rules
        self.store = store
        self.activityController = activityController
    }

    func handleCandidate(_ event: PresenceEvent, validationDate: Date) async throws {
        guard case .validated(let validated) = rules.validate(candidate: event, at: validationDate) else { return }
        try await store.save(validated)
        switch validated.kind {
        case .enter: await activityController.start(arrivedAt: validated.occurredAt)
        case .exit: await activityController.end()
        }
    }
}
