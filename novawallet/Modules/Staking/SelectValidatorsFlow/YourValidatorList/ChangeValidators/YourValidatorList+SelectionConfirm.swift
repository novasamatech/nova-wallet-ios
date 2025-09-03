import Foundation

extension YourValidatorList {
    final class SelectValidatorsConfirmWireframe: SelectValidatorsConfirmWireframeProtocol, ModalAlertPresenting {
        func complete(from view: SelectValidatorsConfirmViewProtocol?) {
            let languages = view?.localizationManager?.selectedLocale.rLanguages
            let title = R.string(
                preferredLanguages: languages ?? []
            ).localizable.commonTransactionSubmitted()

            let navigationController = view?.controller.navigationController
            navigationController?.popToRootViewController(animated: true)
            presentSuccessNotification(title, from: navigationController, completion: nil)
        }
    }
}
