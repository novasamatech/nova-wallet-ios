import Foundation

final class StakingDashboardWireframe: StakingDashboardWireframeProtocol {
    let stateObserver: Observable<StakingDashboardModel>
    let proxySyncService: ProxySyncServiceProtocol

    init(
        stateObserver: Observable<StakingDashboardModel>,
        proxySyncService: ProxySyncServiceProtocol
    ) {
        self.stateObserver = stateObserver
        self.proxySyncService = proxySyncService
    }

    func showMoreOptions(from view: ControllerBackedProtocol?) {
        guard let stakingMoreOptionsView = StakingMoreOptionsViewFactory.createView(stateObserver: stateObserver) else {
            return
        }

        stakingMoreOptionsView.controller.hidesBottomBarWhenPushed = true

        view?.controller.navigationController?.pushViewController(
            stakingMoreOptionsView.controller,
            animated: true
        )
    }

    func showStakingDetails(
        from view: StakingDashboardViewProtocol?,
        option: Multistaking.ChainAssetOption
    ) {
        guard let detailsView = StakingMainViewFactory.createView(
            for: option,
            proxySyncService: proxySyncService
        ) else {
            return
        }

        detailsView.controller.hidesBottomBarWhenPushed = true

        view?.controller.navigationController?.pushViewController(
            detailsView.controller,
            animated: true
        )
    }

    func showStartStaking(from view: StakingDashboardViewProtocol?, chainAsset: ChainAsset) {
        guard let startStakingView = StartStakingInfoViewFactory.createView(
            chainAsset: chainAsset,
            selectedStakingType: nil
        ) else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(from: startStakingView.controller)
        view?.controller.present(navigationController, animated: true, completion: nil)
    }
}
