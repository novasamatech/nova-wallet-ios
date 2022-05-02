import Foundation

struct DisplayWalletViewModel {
    let name: String
    let imageViewModel: ImageViewModelProtocol?
}

extension DisplayWalletViewModel {
    var cellViewModel: StackCellViewModel {
        StackCellViewModel(details: name, imageViewModel: imageViewModel)
    }
}
