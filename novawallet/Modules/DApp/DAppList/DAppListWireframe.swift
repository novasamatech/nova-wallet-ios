import Foundation

final class DAppListWireframe: DAppListWireframeProtocol {
    let proxySyncService: ProxySyncServiceProtocol

    init(proxySyncService: ProxySyncServiceProtocol) {
        self.proxySyncService = proxySyncService
    }

    func showSearch(from view: DAppListViewProtocol?, delegate: DAppSearchDelegate) {
        guard let searchView = DAppSearchViewFactory.createView(with: nil, delegate: delegate) else {
            return
        }

        let navigationController = NovaNavigationController(rootViewController: searchView.controller)
        navigationController.barSettings = NavigationBarSettings.defaultSettings.bySettingCloseButton(false)

        navigationController.modalTransitionStyle = .crossDissolve
        navigationController.modalPresentationStyle = .fullScreen
        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showBrowser(
        from view: DAppListViewProtocol?,
        for result: DAppSearchResult,
        dAppList: [DApp]
    ) {
        let tab = DAppBrowserTab(from: result)

        guard
            let tabsView = DAppBrowserTabListViewFactory.createView(dAppList: dAppList),
            let browserView = DAppBrowserViewFactory.createView(
                with: result.dApp,
                selectedTab: tab
            )
        else {
            return
        }

        tabsView.controller.hidesBottomBarWhenPushed = true
        browserView.controller.hidesBottomBarWhenPushed = true

        let controllers = view?.controller.navigationController?.viewControllers ?? []

        view?.controller.navigationController?.setViewControllers(
            controllers + [tabsView.controller, browserView.controller],
            animated: true
        )
    }

    func showSetting(from view: DAppListViewProtocol?) {
        guard let settingsView = DAppAuthSettingsViewFactory.createView() else {
            return
        }

        let navigationController = NovaNavigationController(rootViewController: settingsView.controller)
        view?.controller.present(navigationController, animated: true, completion: nil)
    }
}
