import Foundation

final class KnownNetworksListWireframe: KnownNetworksListWireframeProtocol {
    func showAddNetwork(
        from view: KnownNetworksListViewProtocol?,
        with knownNetwork: ChainModel?
    ) {
        guard let customNetworkView = CustomNetworkViewFactory.createNetworkAddView(networkToAdd: knownNetwork) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            customNetworkView.controller,
            animated: true
        )
    }
}
