import Foundation

final class TokensManageAddWireframe: TokensManageAddWireframeProtocol, ModalAlertPresenting {
    func complete(from view: TokensManageAddViewProtocol?, result: EvmTokenAddResult, locale: Locale) {
        let title: String

        if result.isNew {
            title = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.addTokenCompletionMessage(result.chainAsset.asset.symbol)
        } else {
            title = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.updateTokenCompletionMessage(result.chainAsset.asset.symbol)
        }

        let presenter = view?.controller.navigationController?.presentingViewController

        presenter?.dismiss(animated: true) { [weak self] in
            self?.presentSuccessNotification(title, from: presenter, completion: nil)
        }
    }
}
