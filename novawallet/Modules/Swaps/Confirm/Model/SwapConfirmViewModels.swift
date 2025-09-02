import Foundation

struct SwapAssetAmountViewModel {
    let imageViewModel: ImageViewModelProtocol?
    let hub: NetworkViewModel
    let amount: String
    let price: String?
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

struct SwapDifferenceModel {
    let diff: Decimal
    let attention: AttentionState
}
