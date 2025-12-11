import Foundation

extension SwitchAccount {
    final class PVAddConfirmWireframe: PVAddConfirmWireframeProtocol {
        func complete(on view: ControllerBackedProtocol?) {
            guard let navigationController = view?.controller.navigationController else {
                return
            }

            navigationController.popToRootViewController(animated: true)
        }
    }
}
