import Foundation

final class AssetsSearchWireframe: AssetsSearchWireframeProtocol {
    func close(view: ControllerBackedProtocol?, completion: (() -> Void)?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: completion)
    }
}
