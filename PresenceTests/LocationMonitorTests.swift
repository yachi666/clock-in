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

    // Monitoring failure is forwarded to delegate synchronously via handleMonitoringFailure(_:).
    func testMonitoringFailureForwardedToDelegate() {
        let (sut, _, fakeDelegate) = makeSUT()
        let fakeError = NSError(domain: "test", code: 1)

        sut.handleMonitoringFailure(fakeError)

        XCTAssertEqual(fakeDelegate.receivedErrors.count, 1)
        if case LocationMonitorError.regionMonitoringFailed(let e) = fakeDelegate.receivedErrors.first! {
            XCTAssertEqual((e as NSError).code, 1)
        } else {
            XCTFail("Expected regionMonitoringFailed error")
        }
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

    // Pre-authorized (.authorizedWhenInUse): startMonitoring should immediately request Always.
    func testStartMonitoringWithAlreadyWhenInUseRequestsAlwaysImmediately() {
        let (sut, fakeManager, _) = makeSUT(status: .authorizedWhenInUse)

        sut.startMonitoring(coordinate: coordinate, radius: radius)

        XCTAssertEqual(fakeManager.requestWhenInUseCount, 0, "Should not request When-In-Use for pre-authorized state")
        XCTAssertEqual(fakeManager.requestAlwaysCount, 1, "Should request Always immediately")
        XCTAssertTrue(fakeManager.startedRegions.isEmpty, "Should not start region yet")
    }

    // Pre-authorized (.authorizedAlways): startMonitoring should start the region immediately.
    func testStartMonitoringWithAlreadyAuthorizedAlwaysStartsRegionImmediately() {
        let (sut, fakeManager, _) = makeSUT(status: .authorizedAlways)

        sut.startMonitoring(coordinate: coordinate, radius: radius)

        XCTAssertEqual(fakeManager.requestWhenInUseCount, 0)
        XCTAssertEqual(fakeManager.requestAlwaysCount, 0)
        XCTAssertEqual(fakeManager.startedRegions.count, 1)
        let region = fakeManager.startedRegions.first as? CLCircularRegion
        XCTAssertEqual(region?.identifier, "workplace")
    }

    // Pre-denied: startMonitoring reports authorizationDenied immediately.
    func testStartMonitoringWithDeniedStatusReportsErrorImmediately() {
        let (sut, fakeManager, fakeDelegate) = makeSUT(status: .denied)

        sut.startMonitoring(coordinate: coordinate, radius: radius)

        XCTAssertEqual(fakeManager.requestWhenInUseCount, 0)
        XCTAssertTrue(fakeManager.startedRegions.isEmpty)
        XCTAssertEqual(fakeDelegate.receivedErrors.count, 1)
        if case LocationMonitorError.authorizationDenied = fakeDelegate.receivedErrors.first! {
            // correct
        } else {
            XCTFail("Expected authorizationDenied error")
        }
    }

    // Declined Always upgrade: second .authorizedWhenInUse callback reports authorizationDenied,
    // no region starts, and subsequent callbacks don't re-request Always or emit duplicate errors.
    func testDeclinedAlwaysUpgradeReportsDeniedAndClearsState() {
        let (sut, fakeManager, fakeDelegate) = makeSUT(status: .authorizedWhenInUse)

        sut.startMonitoring(coordinate: coordinate, radius: radius)
        XCTAssertEqual(fakeManager.requestAlwaysCount, 1, "Should request Always once on start")

        // Simulate user declining the Always upgrade — iOS calls back with .authorizedWhenInUse again
        sut.handleAuthorizationChange()

        XCTAssertEqual(fakeDelegate.receivedErrors.count, 1, "Should report exactly one error")
        if case LocationMonitorError.authorizationDenied = fakeDelegate.receivedErrors.first! {
            // correct
        } else {
            XCTFail("Expected authorizationDenied error")
        }
        XCTAssertTrue(fakeManager.startedRegions.isEmpty, "No region should be started after declined upgrade")
        XCTAssertEqual(fakeManager.requestAlwaysCount, 1, "Should not request Always a second time")

        // Further callbacks must be no-ops (pending cleared)
        sut.handleAuthorizationChange()
        XCTAssertEqual(fakeDelegate.receivedErrors.count, 1, "Should not emit duplicate errors on repeated callback")
        XCTAssertEqual(fakeManager.requestAlwaysCount, 1, "Should not request Always again on repeated callback")
    }

    // handleAuthorizationChange before startMonitoring is called is a no-op.
    func testAuthorizationCallbackBeforeStartMonitoringDoesNothing() {
        let (sut, fakeManager, _) = makeSUT(status: .authorizedWhenInUse)

        sut.handleAuthorizationChange()

        XCTAssertEqual(fakeManager.requestAlwaysCount, 0, "Should ignore callback before monitoring is requested")
        XCTAssertTrue(fakeManager.startedRegions.isEmpty)
    }

    // Repeated .authorizedAlways callbacks do not start the region a second time.
    func testRepeatedAuthorizedAlwaysCallbackDoesNotStartRegionTwice() {
        let (sut, fakeManager, _) = makeSUT()
        sut.startMonitoring(coordinate: coordinate, radius: radius)

        fakeManager.authorizationStatus = .authorizedAlways
        sut.handleAuthorizationChange()
        sut.handleAuthorizationChange()

        XCTAssertEqual(fakeManager.startedRegions.count, 1, "Should not start region a second time")
    }
}
