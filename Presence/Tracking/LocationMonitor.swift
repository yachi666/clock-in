import CoreLocation
import Foundation

protocol LocationMonitorDelegate: AnyObject {
    func locationMonitorDidEnterRegion(at date: Date)
    func locationMonitorDidExitRegion(at date: Date)
}

@MainActor
final class LocationMonitor: NSObject {
    weak var delegate: (any LocationMonitorDelegate)?

    private let manager = CLLocationManager()
    // nonisolated(unsafe): let is immutable; SystemClock.now is thread-safe
    nonisolated(unsafe) private let clock: any Clock

    init(clock: any Clock = SystemClock()) {
        self.clock = clock
        super.init()
        manager.delegate = self
    }

    func startMonitoring(coordinate: CLLocationCoordinate2D, radius: CLLocationDistance) {
        manager.requestWhenInUseAuthorization()
        manager.requestAlwaysAuthorization()
        let region = CLCircularRegion(center: coordinate, radius: radius, identifier: "workplace")
        region.notifyOnEntry = true
        region.notifyOnExit = true
        manager.startMonitoring(for: region)
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
}
