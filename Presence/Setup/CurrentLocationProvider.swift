import CoreLocation
import Foundation

@MainActor
protocol CurrentLocationProviding {
    func currentCoordinate() async throws -> CLLocationCoordinate2D
}

@MainActor
protocol CurrentLocationManaging: AnyObject {
    var delegate: (any CLLocationManagerDelegate)? { get set }
    var authorizationStatus: CLAuthorizationStatus { get }
    var location: CLLocation? { get }
    func requestWhenInUseAuthorization()
    func requestLocation()
}

extension CLLocationManager: CurrentLocationManaging {}

enum CurrentLocationProviderError: LocalizedError, Equatable {
    case authorizationDenied
    case locationUnavailable

    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "Location access is off."
        case .locationUnavailable:
            return "Current location is unavailable."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .authorizationDenied:
            return "Enable Location in Settings, then try again."
        case .locationUnavailable:
            return "Move to an open area and try again."
        }
    }
}

@MainActor
final class CurrentLocationProvider: NSObject, CurrentLocationProviding {
    private let manager: any CurrentLocationManaging
    private var continuation: CheckedContinuation<CLLocationCoordinate2D, Error>?

    init(manager: (any CurrentLocationManaging)? = nil) {
        self.manager = manager ?? CLLocationManager()
        super.init()
        self.manager.delegate = self
    }

    func currentCoordinate() async throws -> CLLocationCoordinate2D {
        switch manager.authorizationStatus {
        case .denied, .restricted:
            throw CurrentLocationProviderError.authorizationDenied
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default:
            break
        }

        if let coordinate = manager.location?.coordinate {
            return coordinate
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()
        }
    }
}

extension CurrentLocationProvider: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        Task { @MainActor [weak self] in
            self?.continuation?.resume(returning: coordinate)
            self?.continuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.continuation?.resume(throwing: error)
            self?.continuation = nil
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in
            if status == .denied || status == .restricted {
                self?.continuation?.resume(throwing: CurrentLocationProviderError.authorizationDenied)
                self?.continuation = nil
            }
        }
    }
}
