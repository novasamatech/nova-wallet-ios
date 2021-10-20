import Foundation

final class NetworkDetailsWireframe: NetworkDetailsWireframeProtocol {
    func showAddConnection(from view: ControllerBackedProtocol?) {
        guard let addConnectionView = AddConnectionViewFactory.createView() else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            addConnectionView.controller,
            animated: true
        )
    }
}
