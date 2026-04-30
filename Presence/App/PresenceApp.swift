import SwiftUI

@main
struct PresenceApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            Text(appState.hasCompletedSetup ? "Presence Dashboard" : "Presence Setup")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
        }
    }
}
