import Foundation
import UIKit

final class NotificationsSetupWireframe: NotificationsSetupWireframeProtocol {
    var completion: (() -> Void)?

    func complete(on view: ControllerBackedProtocol?) {
        view?.controller.dismiss(animated: true, completion: completion)
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
