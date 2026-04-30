import ActivityKit
import SwiftUI
import WidgetKit

@main
struct PresenceWidgetBundle: WidgetBundle {
    var body: some Widget {
        PresenceLiveActivityWidget()
    }
}

struct PresenceLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PresenceActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 6) {
                Text(context.attributes.workplaceName)
                    .font(.headline)
                Text("At work")
                    .font(.caption)
                Text(context.state.arrivedAt, style: .timer)
                    .font(.system(.title3, design: .monospaced))
            }
            .padding()
            .activityBackgroundTint(.black.opacity(0.85))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    Text("At work \(context.state.arrivedAt, style: .timer)")
                        .font(.system(.body, design: .monospaced))
                }
            } compactLeading: {
                Text("In")
            } compactTrailing: {
                Text(context.state.arrivedAt, style: .timer)
            } minimal: {
                Image(systemName: "location.fill")
            }
        }
    }
}
