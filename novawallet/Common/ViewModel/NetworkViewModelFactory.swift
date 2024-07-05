import Foundation

protocol NetworkViewModelFactoryProtocol {
    func createViewModel(from chain: ChainViewModelSource) -> NetworkViewModel
    func createDiffableViewModel(from chain: ChainViewModelSource) -> DiffableNetworkViewModel
}

final class NetworkViewModelFactory: NetworkViewModelFactoryProtocol {
    func createViewModel(from chain: ChainViewModelSource) -> NetworkViewModel {
        let imageViewModel = ImageViewModelFactory.createChainIconOrDefault(from: chain.icon)

        return NetworkViewModel(name: chain.name, icon: imageViewModel)
    }

    func createDiffableViewModel(from chain: ChainViewModelSource) -> DiffableNetworkViewModel {
        let network = createViewModel(from: chain)

        var hasher = Hasher()
        hasher.combine(chain.name)
        hasher.combine(chain.icon)

        let identifier = hasher.finalize()

        return .init(identifier: identifier, network: network)
    }
}
