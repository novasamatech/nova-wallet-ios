import UIKit
import NovaAnalytics

protocol StakingRedirectPresentable {
    func redirectToStaking(from view: ControllerBackedProtocol?)

    func redirectToBittensorStaking(
        from view: ControllerBackedProtocol?,
        source: StakingFlowSource
    )
}

extension StakingRedirectPresentable {
    func redirectToStaking(from view: ControllerBackedProtocol?) {
        selectStakingTab(from: view, completion: nil)
    }

    // Reuses the dashboard's pending navigation of the staking deep link: it opens the positions
    // of a staked wallet and start staking otherwise, and stays on the tab when the chain asset
    // is not available.
    func redirectToBittensorStaking(
        from view: ControllerBackedProtocol?,
        source: StakingFlowSource
    ) {
        let chainAssetId = ChainAssetId(
            chainId: KnowChainId.bittensor,
            assetId: AssetModel.utilityAssetId
        )

        selectStakingTab(from: view) { stakingView in
            stakingView?.openStaking(for: chainAssetId, source: source)
        }
    }
}

// MARK: Private

private extension StakingRedirectPresentable {
    func selectStakingTab(
        from view: ControllerBackedProtocol?,
        completion: ((StakingDashboardViewProtocol?) -> Void)?
    ) {
        let selectTab = {
            // the fullscreen browser covers the tab bar, so it must be minimized
            // for the staking tab to become visible
            BrowserNavigationFactory.createNavigation()?.minimizeBrowser()

            guard let tabBarController = UIApplication.shared.tabBarController else {
                return
            }

            tabBarController.selectedIndex = MainTabBarIndex.staking

            let navigationController = tabBarController
                .viewControllers?[safe: MainTabBarIndex.staking] as? UINavigationController
            navigationController?.popToRootViewController(animated: false)

            completion?(navigationController?.viewControllers.first as? StakingDashboardViewProtocol)
        }

        if let presentingController = view?.controller.presentingViewController {
            presentingController.dismiss(animated: true, completion: selectTab)
        } else {
            selectTab()
        }
    }
}
