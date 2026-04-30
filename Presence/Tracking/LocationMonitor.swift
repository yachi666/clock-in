import CoreLocation
import Foundation

// Narrow abstraction over CLLocationManager for testability.
@MainActor
protocol CLLocationManaging: AnyObject {
    var delegate: (any CLLocationManagerDelegate)? { get set }
    var authorizationStatus: CLAuthorizationStatus { get }
    func requestWhenInUseAuthorization()
    func requestAlwaysAuthorization()
    func startMonitoring(for region: CLRegion)
}

extension CLLocationManager: CLLocationManaging {}

enum LocationMonitorError: Error {
    case authorizationDenied
    case regionMonitoringFailed(Error)
}

@MainActor
protocol LocationMonitorDelegate: AnyObject {
    func locationMonitorDidEnterRegion(at date: Date)
    func locationMonitorDidExitRegion(at date: Date)
    func locationMonitorDidFail(with error: Error)
}

@MainActor
final class LocationMonitor: NSObject {
    weak var delegate: (any LocationMonitorDelegate)?

    private let manager: any CLLocationManaging
    private let clock: any Clock
    private var pendingRegion: CLCircularRegion?

    init(clock: any Clock = SystemClock(), manager: (any CLLocationManaging)? = nil) {
        self.clock = clock
        self.manager = manager ?? CLLocationManager()
        super.init()
        self.manager.delegate = self
    }

    func startMonitoring(coordinate: CLLocationCoordinate2D, radius: CLLocationDistance) {
        let region = CLCircularRegion(center: coordinate, radius: radius, identifier: "workplace")
        region.notifyOnEntry = true
        region.notifyOnExit = true
        pendingRegion = region
        manager.requestWhenInUseAuthorization()
    }

    // Internal for testability; called by the CLLocationManagerDelegate callback.
    func handleAuthorizationChange() {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
        case .authorizedAlways:
            if let region = pendingRegion {
                manager.startMonitoring(for: region)
            }
        case .denied, .restricted:
            delegate?.locationMonitorDidFail(with: LocationMonitorError.authorizationDenied)
        default:
            break
        }
    }
}

extension LocationMonitor: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard region.identifier == "workplace" else { return }
        let timestamp = clock.now
        Task { @MainActor [weak self] in
            self?.delegate?.locationMonitorDidEnterRegion(at: timestamp)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard region.identifier == "workplace" else { return }
        let timestamp = clock.now
        Task { @MainActor [weak self] in
            self?.delegate?.locationMonitorDidExitRegion(at: timestamp)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            self?.handleAuthorizationChange()
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        monitoringDidFailFor region: CLRegion?,
        withError error: Error
    ) {
        Task { @MainActor [weak self] in
            self?.delegate?.locationMonitorDidFail(
                with: LocationMonitorError.regionMonitoringFailed(error)
            )
        }
    }
}
