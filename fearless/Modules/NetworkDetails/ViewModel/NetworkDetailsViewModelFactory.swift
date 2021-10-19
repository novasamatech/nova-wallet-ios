import Foundation

final class NetworkDetailsViewModelFactory: NetworkDetailsViewModelFactoryProtocol {
    func createViewModel(chainModel: ChainModel) -> NetworkDetailsViewModel {
        let defaultNodesViewModel = chainModel.nodes.map { node in
            ManagedNodeConnectionViewModel(
                identifier: node.name,
                name: node.name,
                isSelected: false
            )
        }

        let sections: [(NetworkDetailsSection, [ManagedNodeConnectionViewModel])] = [
            (.defaultNodes, defaultNodesViewModel)
        ]

        return NetworkDetailsViewModel(
            title: chainModel.name,
            autoSelectNodes: false,
            sections: sections
        )
    }
}
