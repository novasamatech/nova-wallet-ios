import Foundation

final class AssetsManageWireframe: AssetsManageWireframeProtocol {
    func close(view: AssetsManageViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: nil)
    }
}
