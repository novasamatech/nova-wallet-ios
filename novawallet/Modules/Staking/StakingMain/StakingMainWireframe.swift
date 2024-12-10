import Foundation

final class StakingMainWireframe: StakingMainWireframeProtocol {
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
        completion: @escaping () -> Void
    ) {
        guard let stakingRewardFiltersView = StakingRewardFiltersViewFactory.createView(
            initialState: initialState,
            delegate: delegate
        ) else {
            return
        }
        let navigationController = NovaNavigationController(rootViewController: stakingRewardFiltersView.controller)
        view?.controller.presentWithCardLayout(navigationController, animated: true, completion: completion)
    }
}
