import Foundation

final class StakingDashboardWireframe: StakingDashboardWireframeProtocol {
    let stateObserver: Observable<StakingDashboardModel>

    init(stateObserver: Observable<StakingDashboardModel>) {
        self.stateObserver = stateObserver
    }

    func showMoreOptions(from view: ControllerBackedProtocol?) {
        guard let stakingMoreOptionsView = StakingMoreOptionsViewFactory.createView(stateObserver: stateObserver) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            stakingMoreOptionsView.controller,
            animated: true
        )
    }
    func showStakingDetails(
        from view: StakingDashboardViewProtocol?,
        option: Multistaking.ChainAssetOption
    ) {
        guard let detailsView = StakingMainViewFactory.createView(for: option) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            detailsView.controller,
            animated: true
        )
    }
}
