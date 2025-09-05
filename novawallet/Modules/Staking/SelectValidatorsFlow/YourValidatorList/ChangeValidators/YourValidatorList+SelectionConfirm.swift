import Foundation
import Foundation_iOS

extension YourValidatorList {
    final class SelectValidatorsConfirmWireframe: SelectValidatorsConfirmWireframeProtocol, ModalAlertPresenting {
        let localizationManager: LocalizationManagerProtocol

        init(localizationManager: LocalizationManagerProtocol) {
            self.localizationManager = localizationManager
        }

        func complete(from view: SelectValidatorsConfirmViewProtocol?) {
            let languages = localizationManager.selectedLocale.rLanguages
            let title = R.string(
                preferredLanguages: languages
            ).localizable.commonTransactionSubmitted()

            let navigationController = view?.controller.navigationController
            navigationController?.popToRootViewController(animated: true)
            presentSuccessNotification(title, from: navigationController, completion: nil)
        }
    }
}
