import Foundation

final class SubtensorClaimRewardsWireframe: SubtensorClaimRewardsWireframeProtocol {
    let state: SubtensorStakingSharedStateProtocol

    init(state: SubtensorStakingSharedStateProtocol) {
        self.state = state
    }
}
