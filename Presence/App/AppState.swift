import Foundation
import Observation

struct WorkplaceDraft: Equatable {
    var latitude: Double
    var longitude: Double
    var radiusMeters: Double
}

@Observable
final class AppState {
    var hasCompletedSetup: Bool
    var workplaceDraft: WorkplaceDraft?

    init(hasCompletedSetup: Bool = false, workplaceDraft: WorkplaceDraft? = nil) {
        self.hasCompletedSetup = hasCompletedSetup
        self.workplaceDraft = workplaceDraft
    }

    func completeSetup(latitude: Double, longitude: Double, radiusMeters: Double) {
        workplaceDraft = WorkplaceDraft(latitude: latitude, longitude: longitude, radiusMeters: radiusMeters)
        hasCompletedSetup = true
    }
}
