import Foundation
import UIKit
import Foundation_iOS

final class ControllerBacked: ControllerBackedProtocol {
    let controller: UIViewController

    init(controller: UIViewController) {
        self.controller = controller
    }

    var isSetup: Bool {
        controller.isViewLoaded
    }
}
