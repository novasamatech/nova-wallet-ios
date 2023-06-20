import Foundation

final class StakingMoreOptionsWireframe: StakingMoreOptionsWireframeProtocol {
    func showBrowser(from view: ControllerBackedProtocol?, for dApp: DApp) {
        guard let browserView = DAppBrowserViewFactory.createView(for: .dApp(model: dApp)) else {
            return
        }

        browserView.controller.hidesBottomBarWhenPushed = true
        view?.controller.navigationController?.pushViewController(browserView.controller, animated: true)
    }

    func showStakingDetails(
        from view: StakingMoreOptionsViewProtocol?,
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
