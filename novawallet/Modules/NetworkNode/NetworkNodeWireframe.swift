import Foundation

final class NetworkNodeWireframe: NetworkNodeWireframeProtocol, AlertPresentable {
    
    func showNetworkDetails(from view: NetworkNodeViewProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }
}
