import Foundation

final class ProxiedsUpdateWireframe: ProxiedsUpdateWireframeProtocol {
    func close(from view: ControllerBackedProtocol?) {
        view?.controller.dismiss(animated: true, completion: nil)
    }

    func close(from view: ControllerBackedProtocol?, andPresent url: URL) {
        guard let presentingController = view?.controller.presentingViewController else {
            return
        }

        view?.controller.dismiss(animated: true) {
            self.showWeb(url: url, from: presentingController, style: .automatic)
        }
    }
}
