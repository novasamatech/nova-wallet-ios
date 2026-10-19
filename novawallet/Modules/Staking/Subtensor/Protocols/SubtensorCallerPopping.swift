import UIKit

protocol SubtensorCallerPopping {
    func popToCaller(from view: ControllerBackedProtocol?)
}

extension SubtensorCallerPopping {
    func popToCaller(from view: ControllerBackedProtocol?) {
        guard
            let controller = view?.controller,
            let navigationController = controller.navigationController,
            let index = navigationController.viewControllers.firstIndex(of: controller),
            index > 0 else {
            return
        }

        navigationController.popToViewController(navigationController.viewControllers[index - 1], animated: true)
    }
}
