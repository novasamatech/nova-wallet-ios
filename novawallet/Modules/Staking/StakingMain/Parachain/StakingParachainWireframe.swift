import Foundation
import SoraFoundation

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
        initialScheduledRequests: [ParachainStaking.DelegatorScheduledRequest]?,
        delegationIdentities: [AccountId: AccountIdentity]?
    ) {
        guard let stakeView = ParaStkStakeSetupViewFactory.createView(
            with: state,
            initialDelegator: initialDelegator,
            initialScheduledRequests: initialScheduledRequests,
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

    func showUnstakingCollatorSelection(
        from view: ControllerBackedProtocol?,
        delegate: ModalPickerViewControllerDelegate,
        viewModels: [LocalizableResource<AccountDetailsSelectionViewModel>],
        context: AnyObject?
    ) {
        let title = LocalizableResource { locale in
            R.string.localizable.stakingRebond(preferredLanguages: locale.rLanguages)
        }

        guard let infoView = ModalPickerFactory.createCollatorsSelectionList(
            viewModels,
            delegate: delegate,
            title: title,
            context: context
        ) else {
            return
        }

        view?.controller.present(infoView, animated: true, completion: nil)
    }

    func showRebondTokens(
        from view: ControllerBackedProtocol?,
        collatorId: AccountId,
        collatorIdentity: AccountIdentity?
    ) {
        guard let rebondView = ParaStkRebondViewFactory.createView(
            for: state,
            selectedCollator: collatorId,
            collatorIdentity: collatorIdentity
        ) else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(from: rebondView.controller)

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showYieldBoost(from view: ControllerBackedProtocol?, initData: ParaStkYieldBoostInitState) {
        guard let yieldBoostView = ParaStkYieldBoostSetupViewFactory.createView(
            with: state,
            initData: initData
        ) else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(from: yieldBoostView.controller)

        view?.controller.present(navigationController, animated: true, completion: nil)
    }
}
