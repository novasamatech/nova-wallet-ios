import Foundation

final class GiftPrepareShareWireframe: GiftPrepareShareWireframeProtocol {
    func completeReclaim(
        from view: ControllerBackedProtocol?,
        with successText: String
    ) {
        view?.controller.navigationController?.popViewController(animated: true)

        presentMultilineSuccessNotification(
            successText,
            from: view?.controller.navigationController?.topViewController as? ControllerBackedProtocol
        )
    }

    func showError(
        from view: ControllerBackedProtocol?,
        title: String,
        message: String,
        actionTitle: String
    ) {
        present(
            message: message,
            title: title,
            closeAction: actionTitle,
            from: view
        )
    }

    func showRetryableError(
        from view: ControllerBackedProtocol?,
        locale: Locale,
        retryAction: @escaping () -> Void
    ) {
        presentRequestStatus(
            on: view,
            locale: locale,
            retryAction: retryAction
        )
    }
}
