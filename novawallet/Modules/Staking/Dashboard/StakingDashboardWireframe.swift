import Foundation

final class StakingDashboardWireframe: StakingDashboardWireframeProtocol {
    var delegatedAccountSyncService: DelegatedAccountSyncServiceProtocol {
        serviceCoordinator.delegatedAccountSyncService
    }

    let stateObserver: Observable<StakingDashboardModel>
    let serviceCoordinator: ServiceCoordinatorProtocol
    let preSyncServiceCoordinator: PreSyncServiceCoordinatorProtocol

    init(
        stateObserver: Observable<StakingDashboardModel>,
        serviceCoordinator: ServiceCoordinatorProtocol,
        preSyncServiceCoordinator: PreSyncServiceCoordinatorProtocol
    ) {
        self.stateObserver = stateObserver
        self.serviceCoordinator = serviceCoordinator
        self.preSyncServiceCoordinator = preSyncServiceCoordinator
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
            delegatedAccountSyncService: delegatedAccountSyncService
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

        view?.controller.presentWithCardLayout(
            navigationController,
            animated: true,
            completion: nil
        )
    }
}
