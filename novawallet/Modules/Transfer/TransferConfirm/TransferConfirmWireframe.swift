import Foundation

final class TransferConfirmWireframe: TransferConfirmWireframeProtocol, ModalAlertPresenting {
    func complete(on view: TransferConfirmCommonViewProtocol?, locale: Locale) {
        let title = R.string.localizable
            .commonTransactionSubmitted(preferredLanguages: locale.rLanguages)

        let presenter = view?.controller.navigationController?.presentingViewController

        presenter?.dismiss(animated: true) { [weak self] in
            self?.presentSuccessNotification(title, from: presenter, completion: nil)
        }
    }

    func completeWithNoKeys(on view: TransferConfirmCommonViewProtocol?) {
        guard let view = view else {
            return
        }

        presentNoSigningView(from: view) {
            let presenter = view.controller.navigationController?.presentingViewController
            presenter?.dismiss(animated: true, completion: nil)
        }
    }
}
