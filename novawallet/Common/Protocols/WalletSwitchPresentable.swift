import Foundation

protocol WalletSwitchPresentable {
    func showWalletSwitch(from view: ControllerBackedProtocol?)
}

extension WalletSwitchPresentable {
    func showWalletSwitch(from view: ControllerBackedProtocol?) {
        guard let accountManagement = WalletSelectionViewFactory.createView() else {
            return
        }

        let navigationController = FearlessNavigationController(
            rootViewController: accountManagement.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }
}
