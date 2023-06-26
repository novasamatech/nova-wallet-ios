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
        guard let detailsView = StakingMainViewFactory.createView(for: option) else {
            return
        }

        detailsView.controller.hidesBottomBarWhenPushed = true

        view?.controller.navigationController?.pushViewController(
            detailsView.controller,
            animated: true
        )
    }

    func showStartStaking(
        from view: StakingDashboardViewProtocol?
    ) {
        guard let startStakingView = StartStakingInfoViewFactory.createView() else {
            return
        }

        let navigationController = NovaNavigationController(
            rootViewController: startStakingView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }
}
