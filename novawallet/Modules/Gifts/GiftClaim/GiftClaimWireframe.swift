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

    func showError(
        from view: ControllerBackedProtocol?,
        title: String,
        message: String,
        actionTitle: String
    ) {
        let presenter = view?.controller.navigationController?.presentingViewController

        present(
            message: message,
            title: title,
            closeAction: actionTitle,
            from: presenter as? ControllerBackedProtocol
        )
    }

    func showRetryableError(
        from view: ControllerBackedProtocol?,
        locale: Locale,
        retryAction: @escaping () -> Void
    ) {
        let presenter = view?.controller.navigationController?.presentingViewController

        presentRequestStatus(
            on: presenter as? ControllerBackedProtocol,
            locale: locale,
            retryAction: retryAction
        )
    }
}
