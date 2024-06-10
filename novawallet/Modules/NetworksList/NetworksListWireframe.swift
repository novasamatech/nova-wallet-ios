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
}
