import Foundation

final class NetworkDetailsViewModelFactory: NetworkDetailsViewModelFactoryProtocol {
    func createViewModel(chainModel: ChainModel) -> NetworkDetailsViewModel {
        NetworkDetailsViewModel(title: chainModel.name, autoSelectNodes: false)
    }
}
