import Foundation

final class StakingNPoolsWireframe: StakingNPoolsWireframeProtocol {
    let state: NPoolsStakingSharedStateProtocol

    init(state: NPoolsStakingSharedStateProtocol) {
        self.state = state
    }

    func showStakeMore(from _: StakingMainViewProtocol?) {
        // TODO: Implement in task for stake more
    }

    func showUnstake(from _: StakingMainViewProtocol?) {
        // TODO: Implement in task for unstake
    }

    func showRedeem(from _: StakingMainViewProtocol?) {
        // TODO: Implement in task for redeem
    }

    func showClaimRewards(from _: StakingMainViewProtocol?) {
        // TODO: Implement in task for claiming rewards
    }
}