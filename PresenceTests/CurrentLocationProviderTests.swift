import CoreLocation
import XCTest
@testable import Presence

@MainActor
final class CurrentLocationProviderTests: XCTestCase {
    final class FakeCurrentLocationManager: CurrentLocationManaging {
        var delegate: (any CLLocationManagerDelegate)?
        var authorizationStatus: CLAuthorizationStatus = .authorizedWhenInUse
        var location: CLLocation?
        var requestWhenInUseCount = 0
        var requestLocationCount = 0

        func requestWhenInUseAuthorization() { requestWhenInUseCount += 1 }
        func requestLocation() { requestLocationCount += 1 }
    }

    func testReturnsCachedCurrentCoordinateWithoutRequestingLocation() async throws {
        let manager = FakeCurrentLocationManager()
        manager.location = CLLocation(latitude: 31.2304, longitude: 121.4737)
        let sut = CurrentLocationProvider(manager: manager)

        let coordinate = try await sut.currentCoordinate()

        XCTAssertEqual(coordinate.latitude, 31.2304, accuracy: 0.00001)
        XCTAssertEqual(coordinate.longitude, 121.4737, accuracy: 0.00001)
        XCTAssertEqual(manager.requestLocationCount, 0)
    }

    func testDeniedAuthorizationThrowsWithoutRequestingLocation() async {
        let manager = FakeCurrentLocationManager()
        manager.authorizationStatus = .denied
        let sut = CurrentLocationProvider(manager: manager)

        do {
            _ = try await sut.currentCoordinate()
            XCTFail("Expected authorization denied")
        } catch {
            XCTAssertEqual(error as? CurrentLocationProviderError, .authorizationDenied)
        }

        XCTAssertEqual(manager.requestLocationCount, 0)
    }

    func testAuthorizationDeniedErrorHasActionableUserGuidance() {
        let error = CurrentLocationProviderError.authorizationDenied

        XCTAssertEqual(error.errorDescription, "Location access is off.")
        XCTAssertEqual(error.recoverySuggestion, "Enable Location in Settings, then try again.")
    }

    func testSetupLocationActionContentReflectsSavingAndSavedStates() {
        XCTAssertEqual(SetupLocationActionContent.title(isSaving: false, didSave: false), "Set Current Location as Office")
        XCTAssertEqual(SetupLocationActionContent.title(isSaving: true, didSave: false), "Locating...")
        XCTAssertEqual(SetupLocationActionContent.title(isSaving: false, didSave: true), "Office Set")
        XCTAssertEqual(SetupLocationActionContent.systemImage(isSaving: false, didSave: true), "checkmark.circle.fill")
    }
}
