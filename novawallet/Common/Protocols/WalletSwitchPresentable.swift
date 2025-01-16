import Foundation

protocol WalletSwitchPresentable {
    var proxySyncService: ProxySyncServiceProtocol { get }

    func showWalletSwitch(from view: ControllerBackedProtocol?)
}

extension WalletSwitchPresentable {
    func showWalletSwitch(from view: ControllerBackedProtocol?) {
        guard let accountManagement = WalletSelectionViewFactory.createView(proxySyncService: proxySyncService) else {
            return
        }

        let navigationController = NovaNavigationController(
            rootViewController: accountManagement.controller
        )

        view?.controller.presentWithCardLayout(
            navigationController,
            animated: true,
            completion: nil
        )
    }
}
