import Foundation

final class StakingMoreOptionsWireframe: StakingMoreOptionsWireframeProtocol {
    func showBrowser(
        from view: ControllerBackedProtocol?,
        with tab: DAppBrowserTab
    ) {
        guard let browserView = DAppBrowserViewFactory.createView(selectedTab: tab) else {
            return
        }

        browserView.controller.hidesBottomBarWhenPushed = true
        view?.controller.navigationController?.pushViewController(browserView.controller, animated: true)
    }

    func showStartStaking(
        from view: StakingMoreOptionsViewProtocol?,
        chainAsset: ChainAsset,
        stakingType: StakingType?
    ) {
        guard let startStakingView = StartStakingInfoViewFactory.createView(
            chainAsset: chainAsset,
            selectedStakingType: stakingType
        ) else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(from: startStakingView.controller)

        view?.controller.presentWithCardLayout(navigationController, animated: true, completion: nil)
    }
}
