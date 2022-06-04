import Foundation

final class ParaStkUnstakeWireframe: ParaStkUnstakeWireframeProtocol {
    let state: ParachainStakingSharedState

    init(state: ParachainStakingSharedState) {
        self.state = state
    }
}
