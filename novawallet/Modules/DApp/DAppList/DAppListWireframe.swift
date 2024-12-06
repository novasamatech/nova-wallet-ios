import Foundation

final class DAppListWireframe: DAppListWireframeProtocol {
    let proxySyncService: ProxySyncServiceProtocol

    init(proxySyncService: ProxySyncServiceProtocol) {
        self.proxySyncService = proxySyncService
    }

    func showSearch(from view: DAppListViewProtocol?, delegate: DAppSearchDelegate) {
        guard let searchView = DAppSearchViewFactory.createView(delegate: delegate) else {
            return
        }

        let navigationController = NovaNavigationController(rootViewController: searchView.controller)
        navigationController.barSettings = NavigationBarSettings.defaultSettings.bySettingCloseButton(false)

        navigationController.modalTransitionStyle = .crossDissolve
        navigationController.modalPresentationStyle = .fullScreen
        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showSetting(from view: DAppListViewProtocol?) {
        guard let settingsView = DAppAuthSettingsViewFactory.createView() else {
            return
        }

        let navigationController = NovaNavigationController(rootViewController: settingsView.controller)
        view?.controller.present(navigationController, animated: true, completion: nil)
    }
}
