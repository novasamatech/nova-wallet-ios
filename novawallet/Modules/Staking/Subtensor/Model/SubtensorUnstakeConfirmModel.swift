import Foundation

struct SubtensorUnstakeConfirmModel {
    let origin: SubtensorOperationOrigin
    let account: MetaChainAccountResponse
    let target: SubtensorStakeTarget
    let validator: SubtensorConfirmValidator
    let unstakeModel: SubtensorUnstakeModel
    let tolerance: BigRational?
    let acknowledgedQuote: SubtensorTradeQuote?
}
