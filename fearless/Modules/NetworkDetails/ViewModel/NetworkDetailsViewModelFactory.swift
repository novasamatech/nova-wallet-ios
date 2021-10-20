import Foundation

final class NetworkDetailsViewModelFactory: NetworkDetailsViewModelFactoryProtocol {
    func createViewModel(
        chainModel: ChainModel,
        autoSelectNodes: Bool,
        selectedNode: ChainNodeModel,
        locale: Locale
    ) -> NetworkDetailsViewModel {
        let defaultSectionViewModel = createSectionViewModel(
            title: R.string.localizable.networkDefaultNodes(preferredLanguages: locale.rLanguages).uppercased(),
            nodes: Array(chainModel.nodes),
            autoSelectNodes: autoSelectNodes,
            selectedNode: selectedNode
        )

        let autoSelectViewModel = NetworkDetailsAutoSelectViewModel(
            autoSelectNodes: autoSelectNodes,
            title: R.string.localizable.networksAutoSelectNodes(preferredLanguages: locale.rLanguages)
        )

        return NetworkDetailsViewModel(
            title: chainModel.name,
            sections: [
                .autoSelectNodes(autoSelectViewModel),
                .defaultNodes(defaultSectionViewModel)
            ],
            actionTitle: R.string.localizable.networkAddNode(preferredLanguages: locale.rLanguages)
        )
    }

    func createSectionViewModel(
        title: String,
        nodes: [ChainNodeModel],
        autoSelectNodes: Bool,
        selectedNode: ChainNodeModel
    ) -> NetworkDetailsSectionViewModel {
        let nodesViewModel = nodes.map { node in
            ManagedNodeConnectionViewModel(
                identifier: node.displayTitle,
                name: node.name,
                isSelected: selectedNode == node
            )
        }

        return NetworkDetailsSectionViewModel(
            cellViewModels: nodesViewModel,
            highlight: !autoSelectNodes,
            title: title
        )
    }
}
