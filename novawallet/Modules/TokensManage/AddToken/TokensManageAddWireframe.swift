import Foundation

final class TokensManageAddWireframe: TokensManageAddWireframeProtocol, ModalAlertPresenting {
    func complete(from view: TokensManageAddViewProtocol?, token: AssetModel, locale: Locale) {
        let title = R.string.localizable.addTokenCompletionMessage(token.symbol, preferredLanguages: locale.rLanguages)

        let presenter = view?.controller.navigationController?.presentingViewController

        presenter?.dismiss(animated: true) { [weak self] in
            self?.presentSuccessNotification(title, from: presenter, completion: nil)
        }
    }
}
