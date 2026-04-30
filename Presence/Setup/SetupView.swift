import MapKit
import SwiftUI

struct SetupView: View {
    @Bindable var appState: AppState

    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    )
    @State private var radiusMeters: Double = 200
    @State private var mapCenter: CLLocationCoordinate2D = CLLocationCoordinate2D(
        latitude: 31.2304, longitude: 121.4737
    )

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $position)
                .onMapCameraChange { context in
                    mapCenter = context.region.center
                }
                .ignoresSafeArea()
                .overlay {
                    // Center crosshair
                    Image(systemName: "plus")
                        .font(.title)
                        .foregroundStyle(.primary)
                        .shadow(radius: 2)
                }

            bottomCard
        }
    }

    private var bottomCard: some View {
        VStack(spacing: 16) {
            Text("Set Workplace")
                .font(.title2.weight(.semibold))

            HStack {
                Text("Radius")
                Spacer()
                Text("\(Int(radiusMeters)) m")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Slider(value: $radiusMeters, in: 100...500, step: 10)

            Button {
                appState.completeSetup(
                    latitude: mapCenter.latitude,
                    longitude: mapCenter.longitude,
                    radiusMeters: radiusMeters
                )
            } label: {
                Text("Start Tracking")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

#Preview {
    SetupView(appState: AppState())
}
