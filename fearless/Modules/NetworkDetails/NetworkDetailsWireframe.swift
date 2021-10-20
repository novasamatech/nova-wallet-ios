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

    func showNodeInfo(
        connectionItem: ConnectionItem,
        mode: NetworkInfoMode,
        from view: ControllerBackedProtocol?
    ) {
        guard let networkInfoView = NetworkInfoViewFactory.createView(
            with: connectionItem,
            mode: mode
        ) else {
            return
        }

        let navigationController = FearlessNavigationController(rootViewController: networkInfoView.controller)
        view?.controller.present(navigationController, animated: true, completion: nil)
    }
}
