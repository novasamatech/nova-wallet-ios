import UIKit

final class DAppSearchWireframe: DAppSearchWireframeProtocol {
    func close(from view: DAppSearchViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true)
    }

    func navigateToStaking(from view: DAppSearchViewProtocol?) {
        // Dismiss the search first
        view?.controller.presentingViewController?.dismiss(animated: true) {
            // Close the browser widget so the tab bar is visible
            let rootContainer = UIApplication.shared.rootContainer
            rootContainer?.browserWidget?.closeBrowser()

            // Switch to the staking tab
            UIApplication.shared.tabBarController?.selectedIndex = MainTabBarIndex.staking
        }
    }
}
