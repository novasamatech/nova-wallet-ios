import Foundation

protocol NetworkViewModelFactoryProtocol {
    func createViewModel(from chain: ChainModel) -> NetworkViewModel
    func createDiffableViewModel(from chain: ChainModel) -> DiffableNetworkViewModel
}

final class NetworkViewModelFactory: NetworkViewModelFactoryProtocol {
    func createViewModel(from chain: ChainModel) -> NetworkViewModel {
        let imageViewModel = RemoteImageViewModel(url: chain.icon)

        return NetworkViewModel(name: chain.name, icon: imageViewModel)
    }

    func createDiffableViewModel(from chain: ChainModel) -> DiffableNetworkViewModel {
        let network = createViewModel(from: chain)

        var hasher = Hasher()
        hasher.combine(chain.name)
        hasher.combine(chain.icon)

        let identifier = hasher.finalize()

        return .init(identifier: identifier, network: network)
    }
}
