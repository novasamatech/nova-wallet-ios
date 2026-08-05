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

            guard
                let tabBarController = UIApplication.shared.tabBarController,
                tabBarController.selectedIndex != MainTabBarIndex.staking
            else {
                return
            }

            let navigationController = tabBarController.selectedViewController as? UINavigationController
            navigationController?.popToRootViewController(animated: false)

            tabBarController.selectedIndex = MainTabBarIndex.staking
        }

        if let presentingController = view?.controller.presentingViewController {
            presentingController.dismiss(animated: true, completion: selectStakingTab)
        } else {
            selectStakingTab()
        }
    }
}
