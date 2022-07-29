import Foundation

protocol NetworkViewModelFactoryProtocol {
    func createViewModel(from chain: ChainModel) -> NetworkViewModel
}

final class NetworkViewModelFactory: NetworkViewModelFactoryProtocol {
    func createViewModel(from chain: ChainModel) -> NetworkViewModel {
        let imageViewModel = RemoteImageViewModel(url: chain.icon)

        return NetworkViewModel(name: chain.name, icon: imageViewModel)
    }
}
