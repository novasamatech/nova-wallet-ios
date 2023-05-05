import Foundation

final class WalletConnectNetworksViewModelFactory {
    private lazy var networkViewModelFactory = NetworkViewModelFactory()

    func createViewModel(from networks: WalletConnectChainsResolution) -> WalletConnectNetworksViewModel {
        let optNetwork = networks.resolved.values.min { $0.addressPrefix < $1.addressPrefix }

        let networkViewModel = optNetwork.map { networkViewModelFactory.createViewModel(from: $0) }

        return .init(
            network: networkViewModel,
            supported: networks.resolved.count,
            unsupported: networks.unresolved.count
        )
    }
}
