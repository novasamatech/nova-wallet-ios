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
    let avgBuyPrice: SubtensorCostBasisRowViewModel
    let youWillEarn: SubtensorCostBasisRowViewModel
    let slippage: String?
    let validatorApy: String?
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

struct SubtensorConfirmViewModelInput {
    let model: SubtensorStakingConfirmModel
    let catalogue: SubtensorSubnetCatalogue?
    let latestQuote: SubtensorTradeQuote?
    let tradesUnavailable: Bool
    let isQuoteFailed: Bool
    let isPriceMoved: Bool
    let price: PriceData?
    let fee: ExtrinsicFeeProtocol?
    let stakeBefore: Balance?
    let signing: SubtensorOperationGate.Verdict
    let costBasis: SubtensorCostBasisState?
}

struct SubtensorConfirmStakeChange: Equatable {
    let before: Balance
    let after: Balance
    let isEstimated: Bool
}

struct SubtensorUnstakeConfirmViewModelInput {
    let model: SubtensorUnstakeConfirmModel
    let catalogue: SubtensorSubnetCatalogue?
    let latestQuote: SubtensorTradeQuote?
    let tradesUnavailable: Bool
    let isQuoteFailed: Bool
    let isPriceMoved: Bool
    let price: PriceData?
    let fee: ExtrinsicFeeProtocol?
    let stakeChange: SubtensorConfirmStakeChange?
    let signing: SubtensorOperationGate.Verdict
    let costBasis: SubtensorCostBasisState
}
