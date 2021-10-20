import Foundation

final class NetworksViewModelFactory: NetworksViewModelFactoryProtocol {
    func createViewModel(
        chains: [ChainModel],
        chainSettings: Set<ChainSettingsModel>,
        locale: Locale
    ) -> NetworksViewModel {
        let chainSortedByName = chains.sorted(by: { $0.name < $1.name })

        let supported = chainSortedByName
            .filter { !$0.isTestnet }
            .map { chain in
                createItemViewModel(
                    chain: chain,
                    chainSettings: chainSettings.first(where: { $0.chainId == chain.chainId }),
                    locale: locale
                )
            }

        let testnets = chainSortedByName
            .filter { $0.isTestnet }
            .map { chain in
                createItemViewModel(
                    chain: chain,
                    chainSettings: chainSettings.first(where: { $0.chainId == chain.chainId }),
                    locale: locale
                )
            }

        let sections: [(NetworksSection, [NetworksItemViewModel])] = {
            if !supported.isEmpty {
                if !testnets.isEmpty {
                    return [
                        (.supported, supported),
                        (.testnets, testnets)
                    ]
                } else {
                    return [(.supported, supported)]
                }
            } else {
                if !testnets.isEmpty {
                    return [(.testnets, testnets)]
                } else {
                    return []
                }
            }
        }()

        return NetworksViewModel(sections: sections)
    }

    private func createItemViewModel(
        chain: ChainModel,
        chainSettings: ChainSettingsModel?,
        locale: Locale
    ) -> NetworksItemViewModel {
        let nodeDescription: String = {
            if let chainSettings = chainSettings {
                if chainSettings.autobalanced {
                    return R.string.localizable.networksAutoSelectNodes(preferredLanguages: locale.rLanguages)
                } else {
                    let nodeUrl = chain.nodes.first?.url // TODO:
                    return nodeUrl?.description ?? "" // TODO:
                }
            } else {
                return R.string.localizable.networksAutoSelectNodes(preferredLanguages: locale.rLanguages)
            }
        }()

        return NetworksItemViewModel(
            chainId: chain.chainId,
            name: chain.name,
            icon: RemoteImageViewModel(url: chain.icon),
            nodeDescription: nodeDescription
        )
    }
}
