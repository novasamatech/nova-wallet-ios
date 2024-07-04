import Foundation

final class NetworksListWireframe: NetworksListWireframeProtocol {
    func showNetworkDetails(
        from view: NetworksListViewProtocol?,
        with chain: ChainModel
    ) {
        guard let networkDetailsView = NetworkDetailsViewFactory.createView(with: chain) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            networkDetailsView.controller,
            animated: true
        )
    }
    
    func showAddNetwork(from view: NetworksListViewProtocol?) {
        guard let knownNetworksListView = KnownNetworksListViewFactory.createView() else {
            return
        }
        
        view?.controller.navigationController?.pushViewController(
            knownNetworksListView.controller,
            animated: true
        )
    }
    
    func showIntegrateOwnNetwork(from view: NetworksListViewProtocol?) {
        guard let addNetworkView = CustomNetworkViewFactory.createNetworkAddView() else {
            return
        }
        
        view?.controller.navigationController?.pushViewController(
            addNetworkView.controller,
            animated: true
        )
    }
}
