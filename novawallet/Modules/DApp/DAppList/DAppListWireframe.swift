import Foundation

final class DAppListWireframe: DAppListWireframeProtocol {
    let delegatedAccountSyncService: DelegatedAccountSyncServiceProtocol

    init(delegatedAccountSyncService: DelegatedAccountSyncServiceProtocol) {
        self.delegatedAccountSyncService = delegatedAccountSyncService
    }

    func showFavorites(from view: (any DAppListViewProtocol)?) {
        guard let favoritesView = DAppFavoritesViewFactory.createView() else {
            return
        }

        presentWithNavigationController(
            favoritesView,
            from: view
        )
    }

    func showSetting(from view: DAppListViewProtocol?) {
        guard let settingsView = DAppAuthSettingsViewFactory.createView() else {
            return
        }

        presentWithNavigationController(
            settingsView,
            from: view
        )
    }

    private func presentWithNavigationController(
        _ view: ControllerBackedProtocol,
        from presentingController: ControllerBackedProtocol?
    ) {
        let navigationController = NovaNavigationController(rootViewController: view.controller)

        presentingController?.controller.presentWithCardLayout(
            navigationController,
            animated: true
        )
    }
}
