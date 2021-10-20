import Foundation

final class NetworkDetailsViewModelFactory: NetworkDetailsViewModelFactoryProtocol {
    func createViewModel(
        chainModel: ChainModel,
        autoSelectNodes: Bool,
        selectedNode: ChainNodeModel,
        locale: Locale
    ) -> NetworkDetailsViewModel {
        let defaultNodesViewModel = chainModel.nodes.map { node in
            ManagedNodeConnectionViewModel(
                identifier: node.displayTitle,
                name: node.name,
                isSelected: selectedNode == node
            )
        }

        return NetworkDetailsViewModel(
            title: chainModel.name,
            sections: [
                .autoSelectNodes(autoSelectNodes),
                .defaultNodes(defaultNodesViewModel, highlight: !autoSelectNodes)
            ],
            actionTitle: R.string.localizable.networkAddNode(preferredLanguages: locale.rLanguages)
        )
    }
}
