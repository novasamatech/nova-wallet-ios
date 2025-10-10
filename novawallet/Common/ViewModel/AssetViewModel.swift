import Foundation

struct AssetViewModel {
    let symbol: String
    let name: String?
    let imageViewModel: ImageViewModelProtocol?

    init(
        symbol: String,
        name: String? = nil,
        imageViewModel: ImageViewModelProtocol?
    ) {
        self.symbol = symbol
        self.name = name
        self.imageViewModel = imageViewModel
    }
}
