import Foundation

final class StakingNPoolsWireframe: StakingNPoolsWireframeProtocol {
    let state: NPoolsStakingSharedStateProtocol

    init(state: NPoolsStakingSharedStateProtocol) {
        self.state = state
    }
}
