import Foundation

struct SubtensorConfirmTileIconsViewModel {
    let pay: ImageViewModelProtocol?
    let receive: ImageViewModelProtocol?
}

struct SubtensorConfirmSwapViewModel {
    let pay: BalanceViewModel
    let receive: LoadableViewModelState<BalanceViewModel>
    let swapRate: LoadableViewModelState<String>
    let isQuoteFailed: Bool
    let avgBuyPrice: SubtensorRowState<SubtensorCostBasisValueViewModel>
    let youWillEarn: SubtensorRowState<SubtensorCostBasisValueViewModel>
    let slippage: String?
    let validatorApy: String?
    let remark: String?
    let feeDisclosure: String?
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

struct SubtensorConfirmViewModel {
    let title: String
    let content: SubtensorConfirmContentViewModel
    let networkFee: BalanceViewModelProtocol?
    let isPriceMoved: Bool
    let action: SubtensorSetupActionViewModel
    let signingHint: String?
}

struct SubtensorConfirmViewModelInput {
    let model: SubtensorConfirmModel
    let catalogue: SubtensorSubnetCatalogue?
    let latestQuote: SubtensorTradeQuote?
    let tradesUnavailable: Bool
    let isQuoteFailed: Bool
    let isPriceMoved: Bool
    let price: PriceData?
    let fee: ExtrinsicFeeProtocol?
    let stakeChange: SubtensorConfirmStakeChange?
    let signing: SubtensorOperationGate.Verdict
    let costBasis: SubtensorCostBasisState?
}

struct SubtensorConfirmStakeChange: Equatable {
    let before: Balance
    let after: Balance
}
