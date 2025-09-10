import Foundation
import Foundation_iOS

final class ExportMnemonicConfirmWireframe: AccountConfirmWireframeProtocol, ModalAlertPresenting {
    let localizationManager: LocalizationManagerProtocol

    init(localizationManager: LocalizationManagerProtocol) {
        self.localizationManager = localizationManager
    }

    func proceed(from view: AccountConfirmViewProtocol?) {
        let title = R.string(preferredLanguages: localizationManager.selectedLocale.rLanguages).localizable.commonConfirmed()

        presentSuccessNotification(title, from: view) {
            DispatchQueue.main.async {
                view?.controller.navigationController?.popToRootViewController(animated: true)
            }
        }
    }
}
