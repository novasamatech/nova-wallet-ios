import Foundation

final class ParaStkYourCollatorsWireframe: ParaStkYourCollatorsWireframeProtocol {
    let state: ParachainStakingSharedState

    init(state: ParachainStakingSharedState) {
        self.state = state
    }

    func showCollatorInfo(
        from view: ParaStkYourCollatorsViewProtocol?,
        collatorInfo: CollatorSelectionInfo
    ) {
        guard let infoView = ParaStkCollatorInfoViewFactory.createView(
            for: state,
            collatorInfo: collatorInfo
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(infoView.controller, animated: true)
    }

    func showManageCollators(
        from view: ParaStkYourCollatorsViewProtocol?,
        options: [StakingManageOption],
        delegate: ModalPickerViewControllerDelegate,
        context: AnyObject?
    ) {
        guard let picker = ModalPickerFactory.createStakingManageSource(
            options: options,
            delegate: delegate,
            context: context
        ) else {
            return
        }

        view?.controller.present(picker, animated: true, completion: nil)
    }

    func showStakeMore(
        from view: ParaStkYourCollatorsViewProtocol?,
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
        from view: ParaStkYourCollatorsViewProtocol?,
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
