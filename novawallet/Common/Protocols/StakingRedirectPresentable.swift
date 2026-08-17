import UIKit

protocol StakingRedirectPresentable {
    func redirectToStaking(from view: ControllerBackedProtocol?)
}

extension StakingRedirectPresentable {
    func redirectToStaking(from view: ControllerBackedProtocol?) {
        let selectStakingTab = {
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
        }

        if let presentingController = view?.controller.presentingViewController {
            presentingController.dismiss(animated: true, completion: selectStakingTab)
        } else {
            selectStakingTab()
        }
    }
}
