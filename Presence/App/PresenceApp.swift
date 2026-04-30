import SwiftData
import SwiftUI

@main
struct PresenceApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            if appState.hasCompletedSetup {
                DashboardView(summary: .sample, attendanceDays: [])
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
