import Foundation

final class NetworkDetailsWireframe: NetworkDetailsWireframeProtocol {
    func showAddNode(
        from view: NetworkDetailsViewProtocol?,
        chainId _: ChainModel.Id
    ) {
        guard let addNodeView = NetworkAddNodeViewFactory.createView() else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            addNodeView.controller,
            animated: true
        )
    }
}
