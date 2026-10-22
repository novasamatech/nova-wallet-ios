import Foundation

struct SubtensorConfirmModel {
    enum Mode {
        case stake(amount: Balance)
        case unstake(SubtensorUnstakeModel)
    }

    let origin: SubtensorOperationOrigin
    let account: MetaChainAccountResponse
    let target: SubtensorStakeTarget
    let validator: SubtensorConfirmValidator
    let mode: Mode
    let tolerance: BigRational?
    var acknowledgedQuote: SubtensorTradeQuote?
    var hasLockedStake = false

    var amount: Balance {
        switch mode {
        case let .stake(amount):
            return amount
        case let .unstake(unstakeModel):
            return unstakeModel.amount
        }
    }

    var direction: SubtensorTradeDirection {
        switch mode {
        case .stake:
            return .buy
        case .unstake:
            return .sell
        }
    }
}
