import Foundation

final class NetworksViewModelFactory: NetworksViewModelFactoryProtocol {
    func createViewModel(chains: [ChainModel], locale _: Locale) -> NetworksViewModel {
        let supported = chains
            .filter { !$0.isTestnet }
            .sorted(by: { $0.name < $1.name })
            .map { chain in
                NetworksItemViewModel(
                    chainId: chain.chainId,
                    name: chain.name,
                    icon: RemoteImageViewModel(url: chain.icon),
                    nodeDescription: "Auto select nodes"
                )
            }

        let testnets = chains
            .filter { $0.isTestnet }
            .sorted(by: { $0.name < $1.name })
            .map { chain in
                NetworksItemViewModel(
                    chainId: chain.chainId,
                    name: chain.name,
                    icon: RemoteImageViewModel(url: chain.icon),
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
