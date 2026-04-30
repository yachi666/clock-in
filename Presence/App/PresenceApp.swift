import SwiftData
import SwiftUI

@main
struct PresenceApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            if appState.hasCompletedSetup {
                Text("Presence Dashboard")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .environment(appState)
            } else {
                SetupView(appState: appState)
                    .environment(appState)
            }
        }
        .modelContainer(for: [
            WorkplaceConfigModel.self,
            RegionEventModel.self,
            AttendanceDayModel.self,
            HolidayCalendarCacheModel.self
        ])
    }
}
