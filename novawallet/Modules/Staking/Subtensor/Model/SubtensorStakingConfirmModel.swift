import Foundation

struct SubtensorStakingConfirmModel {
    let origin: SubtensorOperationOrigin
    let account: MetaChainAccountResponse
    let target: SubtensorStakeTarget
    let validator: SubtensorConfirmValidator
    let amount: Balance
    let tolerance: BigRational?
    let acknowledgedQuote: SubtensorTradeQuote?
}
