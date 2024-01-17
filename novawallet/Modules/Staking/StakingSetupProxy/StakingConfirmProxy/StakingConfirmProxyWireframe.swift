import Foundation

final class StakingConfirmProxyWireframe: StakingConfirmProxyWireframeProtocol, ModalAlertPresenting {
    func complete(from view: ControllerBackedProtocol?) {
        let presenter = view?.controller.navigationController?.presentingViewController

        presenter?.dismiss(animated: true) {
            self.presentSuccessNotification("", from: presenter, completion: nil)
        }
    }
}
