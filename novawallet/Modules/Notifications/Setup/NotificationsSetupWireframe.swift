import Foundation
import UIKit
import SoraFoundation

final class NotificationsSetupWireframe: NotificationsSetupWireframeProtocol, ModalAlertPresenting {
    let localizationManager: LocalizationManagerProtocol
    let completion: (() -> Void)?

    init(localizationManager: LocalizationManagerProtocol, completion: (() -> Void)?) {
        self.localizationManager = localizationManager
        self.completion = completion
    }

    func complete(on view: ControllerBackedProtocol?) {
        let title = R.string.localizable.commonSaved(
            preferredLanguages: localizationManager.selectedLocale.rLanguages
        )

        let presenter = view?.controller.presentingViewController

        view?.controller.dismiss(animated: true) {
            self.completion?()

            self.presentSuccessNotification(title, from: presenter, completion: nil)
        }
    }

    func close(on view: ControllerBackedProtocol?) {
        view?.controller.dismiss(animated: true)
    }

    func show(url: URL, from view: ControllerBackedProtocol?) {
        guard let view = view else {
            return
        }

        showWeb(url: url, from: view.controller, style: .modal)
    }
}
