import Foundation

struct DisplayWalletViewModel {
    let name: String
    let imageViewModel: DrawableIconViewModel?
}

extension DisplayWalletViewModel {
    var cellViewModel: StackCellViewModel {
        StackCellViewModel(details: name, imageViewModel: imageViewModel)
    }
}
