import Foundation

final class AssetsSearchWireframe: AssetsSearchWireframeProtocol {
    func close(view: AssetsSearchViewProtocol?, completion: (() -> Void)?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: completion)
    }
}
