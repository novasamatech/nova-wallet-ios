import Foundation

final class NetworkDetailsViewModelFactory: NetworkDetailsViewModelFactoryProtocol {
    func createViewModel(chainModel: ChainModel, locale: Locale) -> NetworkDetailsViewModel {
        let defaultNodesViewModel = chainModel.nodes.map { node in
            ManagedNodeConnectionViewModel(
                identifier: node.name,
                name: node.name,
                isSelected: false
            )
        }

        return NetworkDetailsViewModel(
            title: chainModel.name,
            sections: [
                .autoSelectNodes(true),
                .defaultNodes(defaultNodesViewModel)
            ],
            actionTitle: R.string.localizable.networkAddNode(preferredLanguages: locale.rLanguages)
        )
    }
}
