import Foundation

final class KnownNetworksListWireframe: KnownNetworksListWireframeProtocol {
    func showAddNetwork(
        from view: NetworksListViewProtocol?,
        with knownNetwork: ChainModel?
    ) {
        let customNetworkView = if let knownNetwork, let node = knownNetwork.nodes.first {
            CustomNetworkViewFactory.createNetworkEditView(
                for: knownNetwork,
                selectedNode: node
            )
        } else {
            CustomNetworkViewFactory.createNetworkAddView()
        }
        
        guard let customNetworkView else { return }
        
        view?.controller.navigationController?.pushViewController(
            customNetworkView, 
            animated: true
        )
    }
}
