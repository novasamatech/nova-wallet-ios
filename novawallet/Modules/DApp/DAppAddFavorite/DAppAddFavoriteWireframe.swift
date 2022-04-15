import Foundation

final class DAppAddFavoriteWireframe: DAppAddFavoriteWireframeProtocol, ModalAlertPresenting {
    func complete(view: DAppAddFavoriteViewProtocol?, locale: Locale) {
        let title = R.string.localizable.commonSaved(preferredLanguages: locale.rLanguages)

        let presenter = view?.controller.navigationController?.presentingViewController

        presenter?.dismiss(animated: true) { [weak self] in
            self?.presentSuccessNotification(title, from: presenter, completion: nil)
        }
    }
}
