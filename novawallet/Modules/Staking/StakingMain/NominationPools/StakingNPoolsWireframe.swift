import Foundation

final class StakingNPoolsWireframe: StakingNPoolsWireframeProtocol {
    let state: NPoolsStakingSharedStateProtocol

    init(state: NPoolsStakingSharedStateProtocol) {
        self.state = state
    }

    func showStakeMore(from _: StakingMainViewProtocol?) {
        // TODO: Implement in task for stake more
    }

    func showUnstake(from view: StakingMainViewProtocol?) {
        guard let unstakeView = NPoolsUnstakeSetupViewFactory.createView(for: state) else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(from: unstakeView.controller)

        view?.controller.present(navigationController, animated: true)
    }

    func showRedeem(from view: StakingMainViewProtocol?) {
        guard let redeemView = NPoolsRedeemViewFactory.createView(for: state) else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(from: redeemView.controller)

        view?.controller.present(navigationController, animated: true)
    }

    func showClaimRewards(from view: StakingMainViewProtocol?) {
        guard let claimRewardsView = NPoolsClaimRewardsViewFactory.createView(for: state) else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(from: claimRewardsView.controller)

        view?.controller.present(navigationController, animated: true)
    }
}
