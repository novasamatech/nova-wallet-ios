import Foundation
import UIKit_iOS

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
        let onDelete: () -> Void = {
            if view?.controller.presentedViewController != nil {
                view?.controller.dismiss(animated: true)
            }

            onNodeDelete()
        }

        guard let manageNode = NetworkManageNodeViewFactory.createView(
            node: node,
            onNodeEdit: onNodeEdit,
            onNodeDelete: onDelete
        ) else { return }

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.nova)

        manageNode.controller.modalTransitioningFactory = factory
        manageNode.controller.modalPresentationStyle = .custom

        view?.controller.present(manageNode.controller, animated: true)
    }

    func showEditNetwork(
        from view: NetworkDetailsViewProtocol?,
        network: ChainModel,
        selectedNode: ChainNodeModel
    ) {
        guard let editNetworkView = CustomNetworkViewFactory.createNetworkEditView(
            for: network,
            selectedNode: selectedNode
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            editNetworkView.controller,
            animated: true
        )
    }

    func showNetworksList(from view: NetworkDetailsViewProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }
}
