import Foundation

final class TransferConfirmWireframe: TransferConfirmWireframeProtocol, ModalAlertPresenting {
    func complete(on view: TransferConfirmCommonViewProtocol?, locale: Locale, completion: @escaping () -> Void) {
        let title = R.string.localizable
            .commonTransactionSubmitted(preferredLanguages: locale.rLanguages)

        let presenter = view?.controller.navigationController?.presentingViewController

        presenter?.dismiss(animated: true) {
            completion()
            self.presentSuccessNotification(title, from: presenter, completion: nil)
        }
    }
}
