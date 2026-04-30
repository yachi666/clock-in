import ActivityKit
import Foundation
import OSLog

// MARK: - Narrow ActivityKit abstractions (enables unit testing without real ActivityKit)

protocol ActivityRequesting: Sendable {
    var areActivitiesEnabled: Bool { get }
    func requestActivity(
        attributes: PresenceActivityAttributes,
        contentState: PresenceActivityAttributes.ContentState,
        staleDate: Date?
    ) throws -> any ActivityEnding
}

protocol ActivityEnding: Sendable {
    @MainActor func end(contentState: PresenceActivityAttributes.ContentState) async
}

// MARK: - Real ActivityKit implementation

struct DefaultActivityRequester: ActivityRequesting {
    var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func requestActivity(
        attributes: PresenceActivityAttributes,
        contentState: PresenceActivityAttributes.ContentState,
        staleDate: Date?
    ) throws -> any ActivityEnding {
        let content = ActivityContent(state: contentState, staleDate: staleDate)
        let activity = try Activity<PresenceActivityAttributes>.request(
            attributes: attributes,
            content: content,
            pushType: nil
        )
        return ActivityKitHandle(activity)
    }
}

// @unchecked Sendable is safe: `activity` is written once during init before the
// handle is shared, then only read/called from the @MainActor end path.
private final class ActivityKitHandle: ActivityEnding, @unchecked Sendable {
    private var activity: Activity<PresenceActivityAttributes>

    init(_ activity: Activity<PresenceActivityAttributes>) {
        self.activity = activity
    }

    @MainActor func end(contentState: PresenceActivityAttributes.ContentState) async {
        await activity.end(ActivityContent(state: contentState, staleDate: nil), dismissalPolicy: .immediate)
    }
}

// MARK: - Production controller

@MainActor
final class PresenceActivityController: PresenceActivityControlling {

    private var currentActivity: (any ActivityEnding)?
    private var currentContentState: PresenceActivityAttributes.ContentState?

    private let client: any ActivityRequesting
    private let clock: any Clock
    private let logger = Logger(subsystem: "com.presence.app", category: "LiveActivity")

    init(
        client: any ActivityRequesting = DefaultActivityRequester(),
        clock: any Clock = SystemClock()
    ) {
        self.client = client
        self.clock = clock
    }

    func start(arrivedAt: Date) async {
        guard client.areActivitiesEnabled else {
            logger.debug("Live Activities disabled; skipping start")
            return
        }
        guard currentActivity == nil else {
            logger.debug("Live Activity already active; skipping duplicate start")
            return
        }

        let now = clock.now
        let elapsed = max(0, now.timeIntervalSince(arrivedAt))
        let staleDate = now.addingTimeInterval(12 * 60 * 60)
        let attributes = PresenceActivityAttributes(workplaceName: "Work")
        let contentState = PresenceActivityAttributes.ContentState(
            arrivedAt: arrivedAt,
            elapsedSeconds: elapsed
        )

        do {
            currentActivity = try client.requestActivity(
                attributes: attributes,
                contentState: contentState,
                staleDate: staleDate
            )
            currentContentState = contentState
        } catch {
            logger.error("Failed to start Live Activity: \(error, privacy: .public)")
        }
    }

    func end() async {
        guard let activity = currentActivity else { return }
        let finalState = currentContentState ?? PresenceActivityAttributes.ContentState(
            arrivedAt: clock.now,
            elapsedSeconds: 0
        )
        await activity.end(contentState: finalState)
        currentActivity = nil
        currentContentState = nil
    }
}
