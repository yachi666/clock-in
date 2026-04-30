import MapKit
import SwiftData
import SwiftUI
import UIKit

enum WorkplaceSetupDefaults {
    static let defaultRadiusMeters: Double = 200
}

enum SetupMapFocusLayout {
    static func markerY(in size: CGSize, bottomReservedHeight: CGFloat = 320) -> CGFloat {
        let visibleHeight = max(0, size.height - bottomReservedHeight)
        let idealY = visibleHeight / 2
        guard visibleHeight > 0 else { return 0 }
        return min(max(idealY, 0), visibleHeight)
    }
}

enum SetupLocationActionContent {
    static func title(isSaving: Bool, didSave: Bool) -> String {
        if didSave { return "Office Set" }
        return isSaving ? "Locating..." : "Set Current Location as Office"
    }

    static func systemImage(isSaving: Bool, didSave: Bool) -> String {
        didSave ? "checkmark.circle.fill" : "location.fill"
    }
}

struct SetupView: View {
    @Bindable var appState: AppState
    let store: AttendanceStore
    let currentLocationProvider: any CurrentLocationProviding

    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    )
    @State private var radiusMeters: Double = WorkplaceSetupDefaults.defaultRadiusMeters
    @State private var mapCenter = CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737)
    @State private var saveError: Error?
    @State private var didApplyInitialDraft = false
    @State private var pulse = false
    @State private var isSavingCurrentLocation = false
    @State private var didSaveCurrentLocation = false

    init(
        appState: AppState,
        store: AttendanceStore,
        currentLocationProvider: (any CurrentLocationProviding)? = nil
    ) {
        self.appState = appState
        self.store = store
        self.currentLocationProvider = currentLocationProvider ?? CurrentLocationProvider()
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                mapLayer
                focusMarker
                    .position(
                        x: proxy.size.width / 2,
                        y: SetupMapFocusLayout.markerY(in: proxy.size)
                    )
                bottomCard
            }
        }
        .background(Color(red: 242 / 255, green: 242 / 255, blue: 247 / 255))
        .onAppear {
            pulse = true
            applyInitialDraftIfNeeded()
        }
    }

    private var mapLayer: some View {
        Map(position: $position) {
            UserAnnotation()
        }
            .onMapCameraChange { context in
                mapCenter = context.region.center
            }
            .saturation(0.25)
            .brightness(0.10)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .overlay {
                Color.white.opacity(0.58)
                    .ignoresSafeArea()
            }
    }

    private var focusMarker: some View {
        ZStack {
            Circle()
                .fill(Color.figmaIndigo.opacity(0.50))
                .frame(width: 96, height: 96)
                .scaleEffect(pulse ? 2.5 : 1)
                .opacity(pulse ? 0 : 0.5)
                .animation(.easeOut(duration: 2).repeatForever(autoreverses: false), value: pulse)

            Circle()
                .fill(Color.figmaIndigo.opacity(0.32))
                .frame(width: 96, height: 96)
                .scaleEffect(pulse ? 2 : 1)
                .opacity(pulse ? 0 : 0.3)
                .animation(.easeOut(duration: 2).delay(0.5).repeatForever(autoreverses: false), value: pulse)

            Circle()
                .fill(Color.figmaIndigo)
                .frame(width: 24, height: 24)
                .overlay {
                    Circle()
                        .stroke(.white, lineWidth: 4)
                    Circle()
                        .fill(.white)
                        .frame(width: 6, height: 6)
                }
                .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
        }
    }

    private var bottomCard: some View {
        VStack(spacing: 0) {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("Office location")
                        .font(.system(size: 26, weight: .semibold, design: .serif))
                        .tracking(-0.4)
                        .foregroundStyle(Color(red: 17 / 255, green: 24 / 255, blue: 39 / 255))

                    Text("Use your current location as the office.\nAuto check-in within 200m.")
                        .font(.system(size: 15, weight: .regular))
                        .lineSpacing(3)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color(red: 107 / 255, green: 114 / 255, blue: 128 / 255))
                        .frame(maxWidth: 300)
                }

                if let error = saveError {
                    VStack(spacing: 8) {
                        Text(error.localizedDescription)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)

                        if let recoverySuggestion = (error as? LocalizedError)?.recoverySuggestion {
                            Text(recoverySuggestion)
                                .font(.caption2)
                                .foregroundStyle(Color(red: 107 / 255, green: 114 / 255, blue: 128 / 255))
                                .multilineTextAlignment(.center)
                        }

                        if error as? CurrentLocationProviderError == .authorizationDenied {
                            Button("Open Settings") {
                                openAppSettings()
                            }
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.black)
                        }
                    }
                }

                Button {
                    Task { await saveCurrentLocationAsWorkplace() }
                } label: {
                    Label(
                        SetupLocationActionContent.title(isSaving: isSavingCurrentLocation, didSave: didSaveCurrentLocation),
                        systemImage: SetupLocationActionContent.systemImage(isSaving: isSavingCurrentLocation, didSave: didSaveCurrentLocation)
                    )
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.black, in: Capsule())
                        .shadow(color: .black.opacity(0.10), radius: 12, y: 6)
                }
                .buttonStyle(.plain)
                .disabled(isSavingCurrentLocation || didSaveCurrentLocation)
                .opacity(isSavingCurrentLocation && !didSaveCurrentLocation ? 0.65 : 1)
            }
            .padding(28)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(.white.opacity(0.45), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.10), radius: 24, y: 8)
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
            .frame(maxWidth: 430)
        }
        .frame(maxWidth: .infinity)
    }

    private static let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )

    private func applyInitialDraftIfNeeded() {
        guard !didApplyInitialDraft, let draft = appState.workplaceDraft else { return }
        didApplyInitialDraft = true
        let coordinate = CLLocationCoordinate2D(latitude: draft.latitude, longitude: draft.longitude)
        mapCenter = coordinate
        position = .region(
            MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        )
    }

    private func saveCurrentLocationAsWorkplace() async {
        isSavingCurrentLocation = true
        didSaveCurrentLocation = false
        saveError = nil
        defer { isSavingCurrentLocation = false }

        do {
            let coordinate = try await currentLocationProvider.currentCoordinate()
            mapCenter = coordinate
            withAnimation(.easeOut(duration: 0.25)) {
                position = .region(
                    MKCoordinateRegion(
                        center: coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                )
            }
            try store.saveWorkplace(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                radiusMeters: radiusMeters
            )
            try store.recordCurrentArrival()
            didSaveCurrentLocation = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            try await Task.sleep(nanoseconds: 550_000_000)
            appState.completeSetup(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                radiusMeters: radiusMeters
            )
        } catch {
            didSaveCurrentLocation = false
            saveError = error
        }
    }

    private func saveWorkplace() {
        do {
            try saveWorkplace(latitude: mapCenter.latitude, longitude: mapCenter.longitude)
        } catch {
            saveError = error
        }
    }

    private func saveWorkplace(latitude: Double, longitude: Double) throws {
        try store.saveWorkplace(
            latitude: latitude,
            longitude: longitude,
            radiusMeters: radiusMeters
        )
        saveError = nil
        appState.completeSetup(
            latitude: latitude,
            longitude: longitude,
            radiusMeters: radiusMeters
        )
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

private extension Color {
    static let figmaIndigo = Color(red: 79 / 255, green: 70 / 255, blue: 229 / 255)
}

#Preview {
    let schema = Schema([WorkplaceConfigModel.self, RegionEventModel.self, AttendanceDayModel.self, HolidayCalendarCacheModel.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])
    let store = AttendanceStore(context: ModelContext(container))
    SetupView(appState: AppState(), store: store)
}
