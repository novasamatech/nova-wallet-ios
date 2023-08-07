import Foundation

final class StakingMoreOptionsWireframe: StakingMoreOptionsWireframeProtocol {
    func showBrowser(from view: ControllerBackedProtocol?, for dApp: DApp) {
        guard let browserView = DAppBrowserViewFactory.createView(for: .dApp(model: dApp)) else {
            return
        }

        browserView.controller.hidesBottomBarWhenPushed = true
        view?.controller.navigationController?.pushViewController(browserView.controller, animated: true)
    }

    func showStartStaking(
        from view: StakingMoreOptionsViewProtocol?,
        option: Multistaking.ChainAssetOption
    ) {
        guard let startStakingView = StartStakingInfoViewFactory.createView(
            chainAsset: option.chainAsset,
            selectedStakingType: option.type
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            startStakingView.controller,
            animated: true
        )
    }
}
