import Foundation

final class NetworkDetailsWireframe: NetworkDetailsWireframeProtocol {
    func showAddNode(
        from view: NetworkDetailsViewProtocol?,
        chainId: ChainModel.Id
    ) {
        guard let addNodeView = NetworkAddNodeViewFactory.createView(with: chainId) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            addNodeView.controller,
            animated: true
        )
    }
}
