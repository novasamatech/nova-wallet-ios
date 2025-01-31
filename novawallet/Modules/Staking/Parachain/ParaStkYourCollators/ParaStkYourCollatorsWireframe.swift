import Foundation

final class ParaStkYourCollatorsWireframe: ParaStkYourCollatorsWireframeProtocol {
    let state: ParachainStakingSharedStateProtocol

    init(state: ParachainStakingSharedStateProtocol) {
        self.state = state
    }

    func showCollatorInfo(
        from view: CollatorStkYourCollatorsViewProtocol?,
        collatorInfo: ParachainStkCollatorSelectionInfo
    ) {
        guard let infoView = CollatorStakingInfoViewFactory.createParachainStakingView(
            for: state,
            collatorInfo: collatorInfo
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(infoView.controller, animated: true)
    }

    func showStakeMore(
        from view: CollatorStkYourCollatorsViewProtocol?,
        initialDelegator: ParachainStaking.Delegator?,
        delegationRequests: [ParachainStaking.DelegatorScheduledRequest]?,
        delegationIdentities: [AccountId: AccountIdentity]?
    ) {
        guard let stakeView = ParaStkStakeSetupViewFactory.createView(
            with: state,
            initialDelegator: initialDelegator,
            initialScheduledRequests: delegationRequests,
            delegationIdentities: delegationIdentities
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(stakeView.controller, animated: true)
    }

    func showUnstake(
        from view: CollatorStkYourCollatorsViewProtocol?,
        initialDelegator: ParachainStaking.Delegator?,
        delegationRequests: [ParachainStaking.DelegatorScheduledRequest]?,
        delegationIdentities: [AccountId: AccountIdentity]?
    ) {
        guard let stakeView = ParaStkUnstakeViewFactory.createView(
            with: state,
            initialDelegator: initialDelegator,
            initialScheduledRequests: delegationRequests,
            delegationIdentities: delegationIdentities
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(stakeView.controller, animated: true)
    }
}
