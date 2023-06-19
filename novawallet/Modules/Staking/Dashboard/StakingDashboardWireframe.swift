import Foundation

final class StakingDashboardWireframe: StakingDashboardWireframeProtocol {
    let stateObserver: Observable<StakingDashboardModel>

    init(stateObserver: Observable<StakingDashboardModel>) {
        self.stateObserver = stateObserver
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
