import Foundation

final class StakingParachainWireframe {
    let state: ParachainStakingSharedState

    init(state: ParachainStakingSharedState) {
        self.state = state
    }
}

extension StakingParachainWireframe: StakingParachainWireframeProtocol {
    func showRewardDetails(
        from view: ControllerBackedProtocol?,
        maxReward: Decimal,
        avgReward: Decimal,
        symbol: String
    ) {
        let infoVew = ModalInfoFactory.createParaStkRewardDetails(
            for: maxReward,
            avgReward: avgReward,
            symbol: symbol
        )

        view?.controller.present(infoVew, animated: true, completion: nil)
    }

    func showStakeTokens(
        from view: ControllerBackedProtocol?,
        initialDelegator: ParachainStaking.Delegator?,
        delegationIdentities: [AccountId: AccountIdentity]?
    ) {
        guard let stakeView = ParaStkStakeSetupViewFactory.createView(
            with: state,
            initialDelegator: initialDelegator,
            delegationIdentities: delegationIdentities
        ) else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(from: stakeView.controller)

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showUnstakeTokens(
        from view: ControllerBackedProtocol?,
        initialDelegator: ParachainStaking.Delegator?,
        initialScheduledRequests: [ParachainStaking.DelegatorScheduledRequest]?,
        delegationIdentities: [AccountId: AccountIdentity]?
    ) {
        guard let unstakeView = ParaStkUnstakeViewFactory.createView(
            with: state,
            initialDelegator: initialDelegator,
            initialScheduledRequests: initialScheduledRequests,
            delegationIdentities: delegationIdentities
        ) else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(from: unstakeView.controller)

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showYourCollators(from view: ControllerBackedProtocol?) {
        guard let collatorsView = ParaStkYourCollatorsViewFactory.createView(for: state) else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(from: collatorsView.controller)

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showRedeemTokens(from view: ControllerBackedProtocol?) {
        guard let redeemView = ParaStkRedeemViewFactory.createView(for: state) else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(from: redeemView.controller)

        view?.controller.present(navigationController, animated: true, completion: nil)
    }
}
