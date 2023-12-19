import Foundation

final class ProxiedsUpdateWireframe: ProxiedsUpdateWireframeProtocol {
    let completion: () -> Void

    init(completion: @escaping () -> Void) {
        self.completion = completion
    }

    func close(from view: ControllerBackedProtocol?) {
        completion()
        view?.controller.dismiss(animated: true)
    }
}
