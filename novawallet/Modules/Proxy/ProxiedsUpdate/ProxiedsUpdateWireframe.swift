import Foundation

final class ProxiedsUpdateWireframe: ProxiedsUpdateWireframeProtocol {
    func close(from view: ControllerBackedProtocol?) {
        view?.controller.dismiss(animated: true, completion: nil)
    }
}
