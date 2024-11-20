import Foundation

final class StakingMoreOptionsWireframe: StakingMoreOptionsWireframeProtocol {
    func showBrowser(from view: ControllerBackedProtocol?, for dApp: DApp) {
        let userInput: DAppSearchResult = .dApp(model: dApp)
        guard let browserView = DAppBrowserViewFactory.createView(
            with: userInput,
            selectedTab: DAppBrowserTab(from: userInput)!
        ) else {
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

        view?.controller.present(navigationController, animated: true, completion: nil)
    }
}
