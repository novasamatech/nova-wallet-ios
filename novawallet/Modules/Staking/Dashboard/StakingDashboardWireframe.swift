import Foundation

final class StakingDashboardWireframe: StakingDashboardWireframeProtocol {
    let stateObserver: Observable<StakingDashboardModel>

    init(stateObserver: Observable<StakingDashboardModel>) {
        self.stateObserver = stateObserver
    }

    func showStakingDetails(
        from _: StakingDashboardViewProtocol?,
        option _: Multistaking.ChainAssetOption
    ) {}
}
