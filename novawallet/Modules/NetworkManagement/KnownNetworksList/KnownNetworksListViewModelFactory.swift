import Foundation

class KnownNetworksListviewModelFactory {
    private let networkViewModelFactory: NetworkViewModelFactoryProtocol

    init(networkViewModelFactory: NetworkViewModelFactoryProtocol) {
        self.networkViewModelFactory = networkViewModelFactory
    }

    func createViewModel(
        with chains: [LightChainModel],
        _ selectedLocale: Locale
    ) -> KnownNetworksListViewLayout.Model {
        var sections: [KnownNetworksListViewLayout.Section] = []

        let addNetworkRow = KnownNetworksListViewLayout.Row.addNetwork(
            IconWithTitleViewModel(
                icon: R.image.iconAddNetwork(),
                title: R.string(preferredLanguages: selectedLocale.rLanguages
                ).localizable.networkAddNetworkManually()
            )
        )

        let chainRows: [KnownNetworksListViewLayout.Row] = chains
            .enumerated()
            .map { index, chain in
                let networkType = chain.options?.contains(.testnet) ?? false
                    ? R.string(preferredLanguages: selectedLocale.rLanguages
                    ).localizable.commonTestnet().uppercased()
                    : nil

                let viewModel = NetworksListViewLayout.NetworkWithConnectionModel(
                    index: index,
                    networkType: networkType,
                    connectionState: .connected,
                    networkState: .enabled,
                    networkModel: networkViewModelFactory.createDiffableViewModel(from: chain)
                )

                return .network(viewModel)
            }

        sections.append(.addNetwork([addNetworkRow]))

        if !chainRows.isEmpty {
            sections.append(.networks(chainRows))
        }

        return KnownNetworksListViewLayout.Model(sections: sections)
    }
}
