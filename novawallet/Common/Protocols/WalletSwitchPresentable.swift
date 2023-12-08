import Foundation

protocol WalletSwitchPresentable {
    func showWalletSwitch(from view: ControllerBackedProtocol?)
}

extension WalletSwitchPresentable {
    func showWalletSwitch(from view: ControllerBackedProtocol?) {
        showDelegateUpdates(from: view)
        return

        guard let accountManagement = WalletSelectionViewFactory.createView() else {
            return
        }

        let navigationController = NovaNavigationController(
            rootViewController: accountManagement.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showDelegateUpdates(from view: ControllerBackedProtocol?) {
        guard let delegateUpdatesView = DelegatedAccountsUpdateViewFactory.createView() else {
            return
        }

        let navigationController = NovaNavigationController(rootViewController: delegateUpdatesView.controller)
        view?.controller.present(navigationController, animated: true)
    }
}
