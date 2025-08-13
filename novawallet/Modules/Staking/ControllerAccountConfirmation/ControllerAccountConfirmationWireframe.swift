import Foundation

final class ControllerAccountConfirmationWireframe: ControllerAccountConfirmationWireframeProtocol {
    func close(view: ControllerBackedProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: nil)
    }
}
