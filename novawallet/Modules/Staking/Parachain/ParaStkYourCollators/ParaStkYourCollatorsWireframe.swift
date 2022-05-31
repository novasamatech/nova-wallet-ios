import Foundation

final class ParaStkYourCollatorsWireframe: ParaStkYourCollatorsWireframeProtocol {
    let state: ParachainStakingSharedState

    init(state: ParachainStakingSharedState) {
        self.state = state
    }
}
