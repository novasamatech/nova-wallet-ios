import Foundation
import SoraFoundation

final class ControllerBacked: ControllerBackedProtocol {
    let controller: UIViewController

    init(controller: UIViewController) {
        self.controller = controller
    }

    var isSetup: Bool {
        controller.isViewLoaded
    }
}
