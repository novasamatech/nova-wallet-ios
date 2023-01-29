import Foundation
import UIKit
import StoreKit

final class InAppUpdatesWireframe: InAppUpdatesWireframeProtocol, WebPresentable {
    func finish(view: InAppUpdatesViewProtocol?) {
        view?.controller.dismiss(animated: true)
    }

    func show(url: URL, from view: InAppUpdatesViewProtocol?) {
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:]) { [weak view] _ in
                view?.controller.dismiss(animated: true)
            }
        }
    }
}
