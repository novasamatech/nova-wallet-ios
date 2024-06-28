import Foundation
import SoraUI

final class NetworkDetailsWireframe: NetworkDetailsWireframeProtocol {
    func showAddNode(
        from view: NetworkDetailsViewProtocol?,
        chainId: ChainModel.Id
    ) {
        guard let addNodeView = NetworkNodeViewFactory.createNodeAddView(with: chainId) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            addNodeView.controller,
            animated: true
        )
    }
    
    func showEditNode(
        from view: NetworkDetailsViewProtocol?,
        node: ChainNodeModel,
        chainId: ChainModel.Id
    ) {
        guard let editNodeView = NetworkNodeViewFactory.createNodeEditView(with: chainId, node) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            editNodeView.controller,
            animated: true
        )
    }
    
    func showManageNode(
        from view: NetworkDetailsViewProtocol?,
        node: ChainNodeModel,
        onNodeEdit: @escaping () -> Void,
        onNodeDelete: @escaping () -> Void
    ) {
        guard let manageNode = NetworkManageNodeViewFactory.createView(
            node: node, onNodeEdit: onNodeEdit,
            onNodeDelete: onNodeDelete
        ) else { return }
        
        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.nova)

        manageNode.controller.modalTransitioningFactory = factory
        manageNode.controller.modalPresentationStyle = .custom
        
        view?.controller.present(manageNode.controller, animated: true)
    }
}
