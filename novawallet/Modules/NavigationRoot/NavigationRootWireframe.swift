import Foundation

final class NavigationRootWireframe: NavigationRootWireframeProtocol {
    let serviceCoordinator: ServiceCoordinatorProtocol

    var proxySyncService: ProxySyncServiceProtocol { serviceCoordinator.proxySyncService }

    init(serviceCoordinator: ServiceCoordinatorProtocol) {
        self.serviceCoordinator = serviceCoordinator
    }

    func showWalletConnect(from view: NavigationRootViewProtocol?) {
        guard
            let walletConnectView = WalletConnectSessionsViewFactory.createViewForCurrentWallet(
                with: serviceCoordinator.dappMediator
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

    func showCloudBackupSettins(from view: NavigationRootViewProtocol?) {
        let navigationController = view?.controller.navigationController

        let optBackupSettings = navigationController?.topViewController as? CloudBackupSettingsViewProtocol

        guard
            optBackupSettings == nil,
            let settingsView = SettingsViewFactory.createView(with: serviceCoordinator),
            let cloudBackupSettings = CloudBackupSettingsViewFactory.createView() else {
            return
        }

        settingsView.controller.hidesBottomBarWhenPushed = true

        view?.controller.navigationController?.popToRootViewController(animated: false)
        navigationController?.pushViewController(settingsView.controller, animated: false)
        navigationController?.pushViewController(cloudBackupSettings.controller, animated: true)
    }
}
