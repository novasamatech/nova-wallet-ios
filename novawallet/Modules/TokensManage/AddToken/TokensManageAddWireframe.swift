import Foundation

final class TokensManageAddWireframe: TokensManageAddWireframeProtocol, ModalAlertPresenting {
    func complete(from view: TokensManageAddViewProtocol?, result: EvmTokenAddResult, locale: Locale) {
        let title: String

        if result.isNew {
            title = R.string.localizable.addTokenCompletionMessage(
                result.chainAsset.asset.symbol,
                preferredLanguages: locale.rLanguages
            )
        } else {
            title = R.string.localizable.updateTokenCompletionMessage(
                result.chainAsset.asset.symbol,
                preferredLanguages: locale.rLanguages
            )
        }

        let presenter = view?.controller.navigationController?.presentingViewController

        presenter?.dismiss(animated: true) { [weak self] in
            self?.presentSuccessNotification(title, from: presenter, completion: nil)
        }
    }
}
