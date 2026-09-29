import Foundation

struct SubtensorConfirmTileViewModel {
    let amount: String
    let price: String?
}

struct SubtensorConfirmTileIconsViewModel {
    let pay: ImageViewModelProtocol?
    let receive: ImageViewModelProtocol?
}

struct SubtensorConfirmSwapViewModel {
    let pay: SubtensorConfirmTileViewModel
    let receive: LoadableViewModelState<SubtensorConfirmTileViewModel>
    let swapRate: LoadableViewModelState<String>
    let slippage: String?
    let validatorApy: String?
    let earnPerMonth: LoadableViewModelState<BalanceViewModelProtocol>?
    let remark: String?
}

struct SubtensorConfirmRootViewModel {
    let amount: BalanceViewModelProtocol
    let stakeAfter: String?
    let apy: String?
}

enum SubtensorConfirmContentViewModel {
    case swap(SubtensorConfirmSwapViewModel)
    case root(SubtensorConfirmRootViewModel)
}

struct SubtensorConfirmActionViewModel: Equatable {
    let title: String
    let isEnabled: Bool
}

struct SubtensorConfirmViewModel {
    let title: String
    let content: SubtensorConfirmContentViewModel
    let networkFee: BalanceViewModelProtocol?
    let isPriceMoved: Bool
    let action: SubtensorConfirmActionViewModel
    let signingHint: String?
}
