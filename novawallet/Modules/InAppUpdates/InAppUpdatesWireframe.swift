import Foundation
import UIKit

final class InAppUpdatesWireframe: InAppUpdatesWireframeProtocol {
    func showUpdates() {
        guard let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) else {
            return
        }

        guard
            let view = InAppUpdatesViewFactory.createView(),
            let topViewController = window.rootViewController?.topModalViewController else {
            return
        }

        topViewController.present(view.controller, animated: true)
    }
}
