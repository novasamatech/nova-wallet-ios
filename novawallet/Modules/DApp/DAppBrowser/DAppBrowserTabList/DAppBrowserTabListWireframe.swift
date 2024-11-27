import Foundation
import UIKit

final class DAppBrowserTabListWireframe: DAppBrowserTabListWireframeProtocol {
    func close(from view: ControllerBackedProtocol?) {
        view?.controller.navigationController?.dismiss(animated: true)
    }
}
