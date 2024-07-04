import Foundation

class NetworkManageNodeWireframe: NetworkManageNodeWireframeProtocol {

    func dismiss(_ view: NetworkManageNodeViewProtocol?) {
        view?.controller.dismiss(animated: true)
    }
}
