import UIKit

final class SubtensorValidatorInfoWireframe: SubtensorValidatorInfoWireframeProtocol {
    func close(view: ControllerBackedProtocol?) {
        guard let controller = view?.controller else {
            return
        }

        if
            let navigationController = controller.navigationController,
            navigationController.viewControllers.first !== controller {
            navigationController.popViewController(animated: true)
        } else {
            controller.dismiss(animated: true)
        }
    }
}
