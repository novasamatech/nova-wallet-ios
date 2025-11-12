import Foundation

final class GiftClaimWireframe: GiftClaimWireframeProtocol {
    func showManageWallets(from view: (any ControllerBackedProtocol)?) {
        guard let manageWalletsView = WalletManageViewFactory.createViewForAdding() else {
            return
        }

        let navigationController = NovaNavigationController(
            rootViewController: manageWalletsView.controller
        )

        view?.controller.presentWithCardLayout(
            navigationController,
            animated: true
        )
    }

    func complete(
        from view: ControllerBackedProtocol?,
        with successText: String
    ) {
        let presenter = view?.controller.navigationController?.presentingViewController

        view?.controller.dismiss(animated: true) { [weak self] in
            self?.presentMultilineSuccessNotification(
                successText,
                from: presenter as? ControllerBackedProtocol
            )
        }
    }
}
