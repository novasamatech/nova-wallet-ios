import Foundation

final class StakingNPoolsWireframe: StakingNPoolsWireframeProtocol {
    let state: NPoolsStakingSharedStateProtocol

    init(state: NPoolsStakingSharedStateProtocol) {
        self.state = state
    }

    func showStakeMore(from view: StakingMainViewProtocol?) {
        guard let stakeMoreView = NominationPoolBondMoreSetupViewFactory.createView(state: state) else {
            return
        }
        let navigationController = NovaNavigationController(
            rootViewController: stakeMoreView.controller
        )
        view?.controller.present(navigationController, animated: true, completion: nil)
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
