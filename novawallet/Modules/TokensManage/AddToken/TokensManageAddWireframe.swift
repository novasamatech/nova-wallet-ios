import Foundation

final class TokensManageAddWireframe: TokensManageAddWireframeProtocol, ModalAlertPresenting {
    func complete(from view: TokensManageAddViewProtocol?, token: AssetModel, locale: Locale) {
        let title = R.string.localizable.addTokenCompletionMessage(token.symbol, preferredLanguages: locale.rLanguages)

        presentSuccessNotification(title, from: view) {
            // Completion is called after viewDidAppear so we need to schedule transition to the next run loop
            DispatchQueue.main.async {
                view?.controller.dismiss(animated: true)
            }
        }
    }
}
