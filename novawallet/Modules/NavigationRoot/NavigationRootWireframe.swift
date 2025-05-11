import Foundation

final class NavigationRootWireframe: NavigationRootWireframeProtocol {
    let dappMediator: DAppInteractionMediating
    let proxySyncService: ProxySyncServiceProtocol
    let serviceCoordinator: ServiceCoordinatorProtocol

    init(
        dappMediator: DAppInteractionMediating,
        proxySyncService: ProxySyncServiceProtocol,
        serviceCoordinator: ServiceCoordinatorProtocol
    ) {
        self.dappMediator = dappMediator
        self.proxySyncService = proxySyncService
        self.serviceCoordinator = serviceCoordinator
    }

    func showWalletConnect(from view: NavigationRootViewProtocol?) {
        guard
            let walletConnectView = WalletConnectSessionsViewFactory.createViewForCurrentWallet(
                with: dappMediator
            ) else {
            return
        }

        walletConnectView.controller.hidesBottomBarWhenPushed = true
        view?.controller.navigationController?.pushViewController(walletConnectView.controller, animated: true)
    }

    func showSettings(from view: NavigationRootViewProtocol?) {
        guard let settingsView = SettingsViewFactory.createView(with: serviceCoordinator) else {
            return
        }

        settingsView.controller.hidesBottomBarWhenPushed = true
        view?.controller.navigationController?.pushViewController(settingsView.controller, animated: true)
    }
}
