import Foundation
import UIKit
import Foundation_iOS

final class NotificationsSetupWireframe: NotificationsSetupWireframeProtocol, ModalAlertPresenting {
    let localizationManager: LocalizationManagerProtocol
    let completion: ((Bool) -> Void)?

    init(localizationManager: LocalizationManagerProtocol, completion: ((Bool) -> Void)?) {
        self.localizationManager = localizationManager
        self.completion = completion
    }

    func complete(on view: ControllerBackedProtocol?) {
        view?.controller.dismiss(animated: true) {
            self.completion?(false)
        }
    }

    func saved(on view: ControllerBackedProtocol?) {
        let title = R.string(preferredLanguages: localizationManager.selectedLocale.rLanguages
        ).localizable.commonSaved()

        let presenter = view?.controller.presentingViewController

        view?.controller.dismiss(animated: true) {
            self.completion?(true)

            if presenter?.presentedViewController == nil {
                self.presentSuccessNotification(title, from: presenter, completion: nil)
            }
        }
    }

    func show(url: URL, from view: ControllerBackedProtocol?) {
        guard let view = view else {
            return
        }

        showWeb(url: url, from: view.controller, style: .modal)
    }
}
