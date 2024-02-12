import Foundation

final class NotificationsSetupWireframe: NotificationsSetupWireframeProtocol {
    func complete(on view: ControllerBackedProtocol?) {
        view?.controller.dismiss(animated: true)
    }
}
