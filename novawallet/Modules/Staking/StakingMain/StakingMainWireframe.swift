import Foundation

final class StakingMainWireframe: StakingMainWireframeProtocol {
    func showChainAssetSelection(
        from view: StakingMainViewProtocol?,
        selectedChainAssetId: ChainAssetId?,
        delegate: AssetSelectionDelegate
    ) {
        let stakingFilter: AssetSelectionFilter = { chainAsset in
            StakingType(rawType: chainAsset.asset.staking) != .unsupported
        }

        guard let selectionView = AssetSelectionViewFactory.createView(
            delegate: delegate,
            selectedChainAssetId: selectedChainAssetId,
            assetFilter: stakingFilter
        ) else {
            return
        }

        let navigationController = NovaNavigationController(
            rootViewController: selectionView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showWalletDetails(from view: ControllerBackedProtocol?, wallet: MetaAccountModel) {
        guard let accountManagementView = AccountManagementViewFactory.createView(for: wallet.identifier) else {
            return
        }

        view?.controller.navigationController?.pushViewController(accountManagementView.controller, animated: true)
    }

    func showPeriodSelection(
        from view: ControllerBackedProtocol?,
        initialState: StakingRewardFiltersPeriod?,
        delegate: StakingRewardFiltersDelegate,
        completion _: @escaping () -> Void
    ) {
        guard let stakingRewardFiltersView = StakingRewardFiltersViewFactory.createView(initialState: initialState, delegate: delegate) else {
            return
        }
        let navigationController = NovaNavigationController(rootViewController: stakingRewardFiltersView.controller)
        view?.controller.present(navigationController, animated: true)
    }
}
