import ActivityKit
import Foundation

public struct PresenceActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var arrivedAt: Date
        public var elapsedSeconds: TimeInterval

        public init(arrivedAt: Date, elapsedSeconds: TimeInterval) {
            self.arrivedAt = arrivedAt
            self.elapsedSeconds = elapsedSeconds
        }
    }

    public var workplaceName: String

    public init(workplaceName: String) {
        self.workplaceName = workplaceName
    }
}
