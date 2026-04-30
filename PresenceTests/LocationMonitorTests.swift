import CoreLocation
import XCTest
@testable import Presence

@MainActor
final class LocationMonitorTests: XCTestCase {

    // MARK: - Fakes

    @MainActor
    final class FakeCLLocationManager: CLLocationManaging {
        var delegate: (any CLLocationManagerDelegate)?
        var authorizationStatus: CLAuthorizationStatus = .notDetermined

        var requestWhenInUseCount = 0
        var requestAlwaysCount = 0
        var startedRegions: [CLRegion] = []

        func requestWhenInUseAuthorization() { requestWhenInUseCount += 1 }
        func requestAlwaysAuthorization() { requestAlwaysCount += 1 }
        func startMonitoring(for region: CLRegion) { startedRegions.append(region) }
    }

    @MainActor
    final class FakeLocationMonitorDelegate: LocationMonitorDelegate {
        var enteredDates: [Date] = []
        var exitedDates: [Date] = []
        var receivedErrors: [Error] = []

        func locationMonitorDidEnterRegion(at date: Date) { enteredDates.append(date) }
        func locationMonitorDidExitRegion(at date: Date) { exitedDates.append(date) }
        func locationMonitorDidFail(with error: Error) { receivedErrors.append(error) }
    }

    // MARK: - Helpers

    private let coordinate = CLLocationCoordinate2D(latitude: 37.33, longitude: -122.03)
    private let radius: CLLocationDistance = 100

    private func makeSUT(
        status: CLAuthorizationStatus = .notDetermined
    ) -> (LocationMonitor, FakeCLLocationManager, FakeLocationMonitorDelegate) {
        let fakeManager = FakeCLLocationManager()
        fakeManager.authorizationStatus = status
        let monitor = LocationMonitor(clock: SystemClock(), manager: fakeManager)
        let fakeDelegate = FakeLocationMonitorDelegate()
        monitor.delegate = fakeDelegate
        return (monitor, fakeManager, fakeDelegate)
    }

    // MARK: - Tests

    // Starting monitoring with .notDetermined requests When-In-Use only
    // and does not start monitoring immediately.
    func testStartMonitoringWithNotDeterminedRequestsWhenInUseOnly() {
        let (sut, fakeManager, _) = makeSUT(status: .notDetermined)

        sut.startMonitoring(coordinate: coordinate, radius: radius)

        XCTAssertEqual(fakeManager.requestWhenInUseCount, 1)
        XCTAssertEqual(fakeManager.requestAlwaysCount, 0)
        XCTAssertTrue(fakeManager.startedRegions.isEmpty)
    }

    // When authorization changes to .authorizedWhenInUse, monitor requests Always.
    func testAuthorizationChangeToWhenInUseRequestsAlways() {
        let (sut, fakeManager, _) = makeSUT()
        sut.startMonitoring(coordinate: coordinate, radius: radius)

        fakeManager.authorizationStatus = .authorizedWhenInUse
        sut.handleAuthorizationChange()

        XCTAssertEqual(fakeManager.requestAlwaysCount, 1)
        XCTAssertTrue(fakeManager.startedRegions.isEmpty)
    }

    // When authorization changes to .authorizedAlways, monitor starts the workplace region.
    func testAuthorizationChangeToAuthorizedAlwaysStartsRegion() {
        let (sut, fakeManager, _) = makeSUT()
        sut.startMonitoring(coordinate: coordinate, radius: radius)

        fakeManager.authorizationStatus = .authorizedAlways
        sut.handleAuthorizationChange()

        XCTAssertEqual(fakeManager.startedRegions.count, 1)
        let region = fakeManager.startedRegions.first as? CLCircularRegion
        XCTAssertNotNil(region)
        XCTAssertEqual(region?.identifier, "workplace")
        XCTAssertTrue(region?.notifyOnEntry ?? false)
        XCTAssertTrue(region?.notifyOnExit ?? false)
    }

    // Monitoring failure is forwarded to delegate.
    func testMonitoringFailureForwardedToDelegate() {
        let (sut, _, fakeDelegate) = makeSUT()
        let fakeError = NSError(domain: "test", code: 1)

        let fakeCLManager = CLLocationManager()
        sut.locationManager(fakeCLManager, monitoringDidFailFor: nil, withError: fakeError)

        // Delegate call is dispatched asynchronously via Task; use expectation.
        let expectation = expectation(description: "error forwarded")
        Task { @MainActor in
            // Yield to let the dispatched Task run.
            await Task.yield()
            XCTAssertEqual(fakeDelegate.receivedErrors.count, 1)
            if case LocationMonitorError.regionMonitoringFailed(let e) = fakeDelegate.receivedErrors.first! {
                XCTAssertEqual((e as NSError).code, 1)
            } else {
                XCTFail("Expected regionMonitoringFailed error")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    // Denied authorization is forwarded as an error.
    func testDeniedAuthorizationForwardedAsError() {
        let (sut, fakeManager, fakeDelegate) = makeSUT()
        sut.startMonitoring(coordinate: coordinate, radius: radius)

        fakeManager.authorizationStatus = .denied
        sut.handleAuthorizationChange()

        XCTAssertEqual(fakeDelegate.receivedErrors.count, 1)
        if case LocationMonitorError.authorizationDenied = fakeDelegate.receivedErrors.first! {
            // correct
        } else {
            XCTFail("Expected authorizationDenied error")
        }
    }

    // Restricted authorization is forwarded as an error.
    func testRestrictedAuthorizationForwardedAsError() {
        let (sut, fakeManager, fakeDelegate) = makeSUT()
        sut.startMonitoring(coordinate: coordinate, radius: radius)

        fakeManager.authorizationStatus = .restricted
        sut.handleAuthorizationChange()

        XCTAssertEqual(fakeDelegate.receivedErrors.count, 1)
        if case LocationMonitorError.authorizationDenied = fakeDelegate.receivedErrors.first! {
            // correct
        } else {
            XCTFail("Expected authorizationDenied error")
        }
    }
}
