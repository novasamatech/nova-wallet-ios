import Foundation

final class WalletConnectNetworksViewModelFactory {
    private lazy var networkViewModelFactory = NetworkViewModelFactory()

    func createViewModel(from networks: WalletConnectChainsResolution) -> WalletConnectNetworksViewModel {
        let optNetwork = networks.resolved.values.min {
            ChainModelCompator.defaultComparator(chain1: $0, chain2: $1)
        }

        let networkViewModel = optNetwork.map { networkViewModelFactory.createViewModel(from: $0) }

        return .init(
            network: networkViewModel,
            supported: networks.resolved.count,
            unsupported: networks.unresolved.count
        )
    }
}
