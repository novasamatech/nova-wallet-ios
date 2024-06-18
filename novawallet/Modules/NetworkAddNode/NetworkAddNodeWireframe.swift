import Foundation

final class NetworkAddNodeWireframe: NetworkAddNodeWireframeProtocol, AlertPresentable {
    
    func showNetworkDetails(from view: NetworkAddNodeViewProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }
}
