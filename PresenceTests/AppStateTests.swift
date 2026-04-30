import XCTest
@testable import Presence

@MainActor
final class AppStateTests: XCTestCase {

    func testCompleteSetupStoresDraftAndMarksSetupComplete() {
        let sut = AppState()

        sut.completeSetup(latitude: 31.2304, longitude: 121.4737, radiusMeters: 300)

        XCTAssertTrue(sut.hasCompletedSetup)
        XCTAssertEqual(sut.workplaceDraft, WorkplaceDraft(
            latitude: 31.2304,
            longitude: 121.4737,
            radiusMeters: 300
        ))
    }

    func testCompleteSetupStoresExactValues() {
        let sut = AppState()

        sut.completeSetup(latitude: 40.7128, longitude: -74.0060, radiusMeters: 150)

        let draft = try! XCTUnwrap(sut.workplaceDraft)
        XCTAssertEqual(draft.latitude, 40.7128, accuracy: 0.00001)
        XCTAssertEqual(draft.longitude, -74.0060, accuracy: 0.00001)
        XCTAssertEqual(draft.radiusMeters, 150)
    }

    func testInitialStateHasNotCompletedSetup() {
        let sut = AppState()

        XCTAssertFalse(sut.hasCompletedSetup)
        XCTAssertNil(sut.workplaceDraft)
    }

    func testCompleteSetupOverwritesPreviousDraft() {
        let sut = AppState()
        sut.completeSetup(latitude: 1.0, longitude: 2.0, radiusMeters: 100)

        sut.completeSetup(latitude: 35.6762, longitude: 139.6503, radiusMeters: 500)

        XCTAssertEqual(sut.workplaceDraft, WorkplaceDraft(
            latitude: 35.6762,
            longitude: 139.6503,
            radiusMeters: 500
        ))
    }
}
