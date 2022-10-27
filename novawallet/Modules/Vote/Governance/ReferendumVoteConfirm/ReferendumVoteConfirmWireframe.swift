import Foundation

final class ReferendumVoteConfirmWireframe: ReferendumVoteConfirmWireframeProtocol, ModalAlertPresenting {
    func complete(on view: ReferendumVoteConfirmViewProtocol?, locale: Locale) {
        let title = R.string.localizable
            .commonTransactionSubmitted(preferredLanguages: locale.rLanguages)

        let presenter = view?.controller.navigationController?.presentingViewController

        presenter?.dismiss(animated: true) { [weak self] in
            self?.presentSuccessNotification(title, from: presenter, completion: nil)
        }
    }
}
