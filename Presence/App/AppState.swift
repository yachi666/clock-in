import Foundation
import Observation

@Observable
final class AppState {
    var hasCompletedSetup: Bool

    init(hasCompletedSetup: Bool = false) {
        self.hasCompletedSetup = hasCompletedSetup
    }
}
