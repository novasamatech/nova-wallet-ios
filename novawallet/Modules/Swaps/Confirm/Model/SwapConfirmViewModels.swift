struct SwapAssetAmountViewModel {
    let imageViewModel: ImageViewModelProtocol?
    let hub: NetworkViewModel
    let balance: BalanceViewModelProtocol
}

struct DifferenceViewModel {
    let details: String
    let attention: AttentionState
}

enum AttentionState {
    case high
    case medium
    case low
}
