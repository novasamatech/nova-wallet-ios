import Foundation

final class NetworksViewModelFactory: NetworksViewModelFactoryProtocol {
    func createViewModel(chains: [ChainModel], locale _: Locale) -> NetworksViewModel {
        let supported = chains
            .filter { !$0.isTestnet }
            .map { chain in
                NetworksItemViewModel(
                    name: chain.name,
                    icon: chain.icon,
                    nodeDescription: "Auto select nodes"
                )
            }

        let testnets = chains
            .filter { $0.isTestnet }
            .map { chain in
                NetworksItemViewModel(
                    name: chain.name,
                    icon: chain.icon,
                    nodeDescription: "Auto select nodes"
                )
            }

        return NetworksViewModel(
            sections: [
                (.supported, supported),
                (.testnets, testnets)
            ]
        )
    }
}
