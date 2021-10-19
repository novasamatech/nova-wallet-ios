import Foundation

struct NetworksItemViewModel {
    let chainId: ChainModel.Id
    let name: String
    let icon: ImageViewModelProtocol?
    let nodeDescription: String
}
