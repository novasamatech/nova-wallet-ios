import Foundation

final class DAppNetworksViewModelFactory {
    private lazy var networkViewModelFactory = NetworkViewModelFactory()

    func createViewModel(from networks: DAppChainsResolution) -> DAppNetworksViewModel {
        let optNetwork = networks.resolved.min { chain1, chain2 in
            ChainModelCompator.defaultComparator(chain1: chain1, chain2: chain2)
        }

        let networkViewModel = optNetwork.map { networkViewModelFactory.createViewModel(from: $0) }

        return .init(
            network: networkViewModel,
            supported: networks.resolved.count,
            unsupported: networks.unresolved.count
        )
    }

    func createChainNamesString(from chains: [ChainModel], maxCount: Int, locale: Locale) -> String {
        let namedChains = chains.prefix(maxCount)
        let remainedCount = max(chains.count, maxCount) - maxCount

        let name = namedChains.map(\.name).joined(with: .commaSpace)

        if remainedCount > 0 {
            return R.string(preferredLanguages: locale.rLanguages).localizable.commonMoreFormat(
                name,
                "\(remainedCount)"
            )
        } else {
            return name
        }
    }
}
