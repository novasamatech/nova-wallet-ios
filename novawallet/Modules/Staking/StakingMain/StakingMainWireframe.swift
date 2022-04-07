import Foundation

final class StakingMainWireframe: StakingMainWireframeProtocol {
    let state: StakingSharedState

    init(state: StakingSharedState) {
        self.state = state
    }

    func showSetupAmount(from view: StakingMainViewProtocol?) {
        guard let amountView = StakingAmountViewFactory.createView(with: nil, stakingState: state) else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(from: amountView.controller)

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func proceedToSelectValidatorsStart(
        from view: StakingMainViewProtocol?,
        existingBonding: ExistingBonding
    ) {
        guard let recommendedView = SelectValidatorsStartViewFactory.createChangeTargetsView(
            with: existingBonding,
            stakingState: state
        ) else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(
            from: recommendedView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showRewardDetails(from view: ControllerBackedProtocol?, maxReward: Decimal, avgReward: Decimal) {
        let infoVew = ModalInfoFactory.createRewardDetails(for: maxReward, avgReward: avgReward)

        view?.controller.present(infoVew, animated: true, completion: nil)
    }

    func showRewardPayoutsForNominator(from view: ControllerBackedProtocol?, stashAddress: AccountAddress) {
        guard let rewardPayoutsView = StakingRewardPayoutsViewFactory
            .createViewForNominator(for: state, stashAddress: stashAddress) else { return }

        let navigationController = ImportantFlowViewFactory.createNavigation(
            from: rewardPayoutsView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showRewardPayoutsForValidator(from view: ControllerBackedProtocol?, stashAddress: AccountAddress) {
        guard let rewardPayoutsView = StakingRewardPayoutsViewFactory
            .createViewForValidator(for: state, stashAddress: stashAddress) else { return }

        let navigationController = ImportantFlowViewFactory.createNavigation(
            from: rewardPayoutsView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showNominatorValidators(from view: ControllerBackedProtocol?) {
        guard let validatorsView = YourValidatorListViewFactory.createView(for: state) else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(
            from: validatorsView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showControllerAccount(from view: ControllerBackedProtocol?) {
        guard let controllerAccount = ControllerAccountViewFactory.createView(for: state) else {
            return
        }
        let navigationController = ImportantFlowViewFactory.createNavigation(
            from: controllerAccount.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showAccountsSelection(from view: StakingMainViewProtocol?) {
        guard let accountsView = WalletManagementViewFactory.createViewForSwitch() else {
            return
        }

        accountsView.controller.hidesBottomBarWhenPushed = true

        view?.controller.navigationController?.pushViewController(
            accountsView.controller,
            animated: true
        )
    }

    func showRewardDestination(from view: ControllerBackedProtocol?) {
        guard let displayView = StakingRewardDestSetupViewFactory.createView(for: state) else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(
            from: displayView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showBondMore(from view: ControllerBackedProtocol?) {
        guard let bondMoreView = StakingBondMoreViewFactory.createView(from: state) else { return }
        let navigationController = ImportantFlowViewFactory.createNavigation(
            from: bondMoreView.controller
        )
        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showUnbond(from view: ControllerBackedProtocol?) {
        guard let unbondView = StakingUnbondSetupViewFactory.createView(for: state) else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(from: unbondView.controller)

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showRedeem(from view: ControllerBackedProtocol?) {
        guard let redeemView = StakingRedeemViewFactory.createView(for: state) else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(
            from: redeemView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showRebond(from view: ControllerBackedProtocol?, option: StakingRebondOption) {
        let rebondView: ControllerBackedProtocol? = {
            switch option {
            case .all:
                return StakingRebondConfirmationViewFactory.createView(for: .all, state: state)
            case .last:
                return StakingRebondConfirmationViewFactory.createView(for: .last, state: state)
            case .customAmount:
                return StakingRebondSetupViewFactory.createView(for: state)
            }
        }()

        guard let controller = rebondView?.controller else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(from: controller)

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showAnalytics(from view: ControllerBackedProtocol?, mode: AnalyticsContainerViewMode) {
        let analyticsView = AnalyticsContainerViewFactory.createView(mode: mode, stakingState: state)
        analyticsView.controller.hidesBottomBarWhenPushed = true
        view?.controller.navigationController?.pushViewController(analyticsView.controller, animated: true)
    }

    func showYourValidatorInfo(_ stashAddress: AccountAddress, from view: ControllerBackedProtocol?) {
        guard let validatorInfoView = ValidatorInfoViewFactory.createView(
            with: stashAddress,
            state: state
        ) else { return }
        let navigationController = FearlessNavigationController(rootViewController: validatorInfoView.controller)
        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showChainAssetSelection(
        from view: StakingMainViewProtocol?,
        selectedChainAssetId: ChainAssetId?,
        delegate: AssetSelectionDelegate
    ) {
        let stakingFilter: AssetSelectionFilter = { _, asset in asset.staking != nil }

        guard let selectionView = AssetSelectionViewFactory.createView(
            delegate: delegate,
            selectedChainId: selectedChainAssetId,
            assetFilter: stakingFilter
        ) else {
            return
        }

        let navigationController = FearlessNavigationController(
            rootViewController: selectionView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }
}
