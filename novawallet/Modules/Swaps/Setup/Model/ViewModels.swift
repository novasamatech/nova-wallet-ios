struct SwapsAssetViewModel {
    let symbol: String
    let imageViewModel: ImageViewModelProtocol?
    let hub: NetworkViewModel
}

struct EmptySwapsAssetViewModel {
    let imageViewModel: ImageViewModelProtocol?
    let title: String
    let subtitle: String
}

enum SwapAssetInputViewModel {
    case asset(SwapsAssetViewModel)
    case empty(EmptySwapsAssetViewModel)
}

struct SwapFeeViewModel {
    var isEditable: Bool
    var balanceViewModel: BalanceViewModelProtocol
}

enum TextFieldFocus {
    case payAsset
    case receiveAsset
}

struct SwapPriceDifferenceViewModel {
    let price: String?
    let difference: DifferenceViewModel?
}
