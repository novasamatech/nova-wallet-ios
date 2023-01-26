import Foundation
import UIKit

final class InAppUpdatesWireframe: InAppUpdatesWireframeProtocol, WebPresentable {
    func finish(view: InAppUpdatesViewProtocol?) {
        view?.controller.dismiss(animated: true)
    }

    func show(url: URL, from view: InAppUpdatesViewProtocol?) {
        guard let view = view, let presentingController = view.controller.presentingViewController else {
            return
        }
        view.controller.dismiss(animated: true) { [weak self] in
            self?.showWeb(
                url: url,
                from: presentingController,
                style: .automatic
            )
        }
    }
}
