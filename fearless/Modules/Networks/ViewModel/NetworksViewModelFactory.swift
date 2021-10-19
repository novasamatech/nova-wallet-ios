import Foundation

final class NetworksViewModelFactory: NetworksViewModelFactoryProtocol {
    func createViewModel(
        chains: [ChainModel],
        chainSettings: Set<ChainSettingsModel>,
        locale: Locale
    ) -> NetworksViewModel {
        let supported = chains
            .filter { !$0.isTestnet }
            .sorted(by: { $0.name < $1.name })
            .map { chain in
                createItemViewModel(
                    chain: chain,
                    chainSettings: chainSettings.first(where: { $0.chainId == chain.chainId }),
                    locale: locale
                )
            }

        let testnets = chains
            .filter { $0.isTestnet }
            .sorted(by: { $0.name < $1.name })
            .map { chain in
                createItemViewModel(
                    chain: chain,
                    chainSettings: chainSettings.first(where: { $0.chainId == chain.chainId }),
                    locale: locale
                )
            }

        return NetworksViewModel(
            sections: [
                (.supported, supported),
                (.testnets, testnets)
            ]
        )
    }

    private func createItemViewModel(
        chain: ChainModel,
        chainSettings: ChainSettingsModel?,
        locale _: Locale
    ) -> NetworksItemViewModel {
        let nodeDescription: String = {
            if let chainSettings = chainSettings {
                if chainSettings.autobalanced {
                    return "Auto select nodes"
                } else {
                    let nodeUrl = chain.nodes.first?.url // TODO:
                    return nodeUrl?.description ?? "" // TODO:
                }
            } else {
                return "Auto select nodes"
            }
        }()

        return NetworksItemViewModel(
            name: chain.name,
            icon: RemoteImageViewModel(url: chain.icon),
            nodeDescription: nodeDescription
        )
    }
}
