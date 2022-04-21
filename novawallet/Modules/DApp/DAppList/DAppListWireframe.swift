import Foundation

final class DAppListWireframe: DAppListWireframeProtocol {
    func showWalletSelection(from view: DAppListViewProtocol?) {
        guard let accountsView = WalletManagementViewFactory.createViewForSwitch() else {
            return
        }

        accountsView.controller.hidesBottomBarWhenPushed = true

        view?.controller.navigationController?.pushViewController(accountsView.controller, animated: true)
    }

    func showSearch(from view: DAppListViewProtocol?, delegate: DAppSearchDelegate) {
        guard let searchView = DAppSearchViewFactory.createView(with: nil, delegate: delegate) else {
            return
        }

        let navigationController = FearlessNavigationController(rootViewController: searchView.controller)
        navigationController.barSettings = NavigationBarSettings.defaultSettings.bySettingCloseButton(false)

        navigationController.modalTransitionStyle = .crossDissolve
        navigationController.modalPresentationStyle = .fullScreen
        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showBrowser(from view: DAppListViewProtocol?, for result: DAppSearchResult) {
        guard let browserView = DAppBrowserViewFactory.createView(for: result) else {
            return
        }

        browserView.controller.hidesBottomBarWhenPushed = true
        view?.controller.navigationController?.pushViewController(browserView.controller, animated: true)
    }

    func showSetting(from view: DAppListViewProtocol?) {
        guard let settingsView = DAppAuthSettingsViewFactory.createView() else {
            return
        }

        let navigationController = FearlessNavigationController(rootViewController: settingsView.controller)
        view?.controller.present(navigationController, animated: true, completion: nil)
    }
}
