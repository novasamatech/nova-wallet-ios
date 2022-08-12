import Foundation

extension SwitchAccount {
    final class ParitySignerAddConfirmWireframe: ParitySignerAddConfirmWireframeProtocol {
        func complete(on view: ControllerBackedProtocol?) {
            guard let navigationController = view?.controller.navigationController else {
                return
            }

            navigationController.popToRootViewController(animated: true)
        }
    }
}
