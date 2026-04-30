import CoreLocation
import OSLog
import SwiftData
import SwiftUI

/// Root view: reads persisted workplace on launch, routes to Setup or Dashboard,
/// and owns the tracking infrastructure lifetime.
@MainActor
struct RootView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var appState = AppState()
    @State private var storeLoadError = false

    // Held as @State so their lifetimes are tied to this view.
    @State private var trackingSession = TrackingSession()

    private let logger = Logger(subsystem: "com.presence.app", category: "Setup")

    var body: some View {
        Group {
            if storeLoadError {
                ContentUnavailableView {
                    Label("Configuration Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text("Could not load your saved workplace.")
                } actions: {
                    Button("Try Again") {
                        storeLoadError = false
                        Task { await loadPersistedSetup() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if appState.hasCompletedSetup {
                DashboardLoader()
                    .environment(appState)
            } else {
                SetupView(
                    appState: appState,
                    store: AttendanceStore(context: modelContext)
                )
                .environment(appState)
            }
        }
        .task { await loadPersistedSetup() }
        .onChange(of: appState.hasCompletedSetup) { _, completed in
            if completed, trackingSession.locationMonitor == nil, let draft = appState.workplaceDraft {
                startTracking(latitude: draft.latitude, longitude: draft.longitude, radiusMeters: draft.radiusMeters)
            }
        }
    }

    private func loadPersistedSetup() async {
        let store = AttendanceStore(context: modelContext)
        do {
            guard let config = try store.fetchWorkplace(), config.completedSetup else { return }
            appState.completeSetup(latitude: config.latitude, longitude: config.longitude, radiusMeters: config.radiusMeters)
            startTracking(latitude: config.latitude, longitude: config.longitude, radiusMeters: config.radiusMeters)
        } catch {
            logger.error("Failed to load persisted workplace config: \(error, privacy: .public)")
            storeLoadError = true
        }
    }

    private func startTracking(latitude: Double, longitude: Double, radiusMeters: Double) {
        guard trackingSession.locationMonitor == nil else { return }
        let store = AttendanceStore(context: modelContext)
        let activityController = PresenceActivityController()
        let coordinator = TrackingCoordinator(store: store, activityController: activityController)
        let monitor = LocationMonitor()
        let bridge = LocationEventBridge(coordinator: coordinator)
        monitor.delegate = bridge
        monitor.startMonitoring(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            radius: radiusMeters
        )
        trackingSession.coordinator = coordinator
        trackingSession.locationMonitor = monitor
        trackingSession.bridge = bridge
    }
}

// MARK: - Tracking session container

/// Holds tracking objects as a reference type so @State can capture them.
/// @MainActor isolation serialises all access, satisfying Sendable.
@MainActor
private final class TrackingSession {
    var locationMonitor: LocationMonitor?
    var coordinator: TrackingCoordinator?
    var bridge: LocationEventBridge?
}
