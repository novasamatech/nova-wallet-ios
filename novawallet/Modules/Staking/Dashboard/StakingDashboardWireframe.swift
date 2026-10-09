import Foundation

final class StakingDashboardWireframe: StakingDashboardWireframeProtocol {
    let stateObserver: Observable<StakingDashboardModel>
    let delegatedAccountSyncService: DelegatedAccountSyncServiceProtocol
    let subtensorFlowState: SubtensorStakingFlowStateProtocol

    init(
        stateObserver: Observable<StakingDashboardModel>,
        delegatedAccountSyncService: DelegatedAccountSyncServiceProtocol,
        subtensorFlowState: SubtensorStakingFlowStateProtocol
    ) {
        self.stateObserver = stateObserver
        self.delegatedAccountSyncService = delegatedAccountSyncService
        self.subtensorFlowState = subtensorFlowState
    }

    func showMoreOptions(from view: ControllerBackedProtocol?) {
        guard let stakingMoreOptionsView = StakingMoreOptionsViewFactory.createView(
            stateObserver: stateObserver,
            subtensorFlowState: subtensorFlowState
        ) else {
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
            delegatedAccountSyncService: delegatedAccountSyncService,
            subtensorFlowState: subtensorFlowState
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
            selectedStakingType: nil,
            subtensorFlowState: subtensorFlowState
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
