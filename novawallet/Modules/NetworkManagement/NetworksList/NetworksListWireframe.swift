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
        guard
            let view,
            let knownNetworksListView = KnownNetworksListViewFactory.createView(successAddPresenting: (self, view))
        else {
            return
        }
        
        view.controller.navigationController?.pushViewController(
            knownNetworksListView.controller,
            animated: true
        )
    }
    
    func showIntegrateOwnNetwork(from view: NetworksListViewProtocol?) {
        guard
            let view,
            let addNetworkView = CustomNetworkViewFactory.createNetworkAddView(successPresenting: (self, view))
        else {
            return
        }
        
        view.controller.navigationController?.pushViewController(
            addNetworkView.controller,
            animated: true
        )
    }
}
