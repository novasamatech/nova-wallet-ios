import Foundation

struct SubtensorOperationResultPrices: Equatable {
    let taoPrice: PriceData?
    let alphaSpot: Balance?
}

struct SubtensorOperationResultRequest {
    let operation: SubtensorStakingOperation
    let origin: SubtensorOperationOrigin
    let account: MetaChainAccountResponse
    let target: SubtensorStakeTarget
    let payAmount: Balance
    let quote: SubtensorTradeQuote?
    let slippage: BigRational?
    let validator: SubtensorConfirmValidator
    let estimatedNetworkFee: ExtrinsicFeeProtocol
    let stakeBefore: Balance
    let groupHotkeyCount: Int
    let emptiesPosition: Bool
    let prices: SubtensorOperationResultPrices
    let costBasis: SubtensorCostBasisState?
}
