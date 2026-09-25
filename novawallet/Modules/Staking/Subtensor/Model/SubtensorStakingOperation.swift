import Foundation

struct SubtensorNovaFee: Equatable {
    let amount: Balance
    let beneficiary: AccountId
}

enum SubtensorStakingOperation: Equatable {
    case rootStake(hotkey: AccountId, amount: Balance)
    case rootUnstake(hotkey: AccountId, amount: Balance)
    case rootUnstakeAll(hotkey: AccountId)
    case subnetBuy(hotkey: AccountId, netuid: UInt16, grossTao: Balance, limitPrice: Balance)
    case subnetSell(hotkey: AccountId, netuid: UInt16, alpha: Balance, limitPrice: Balance)
    case subnetSellAll(hotkey: AccountId, netuid: UInt16, alpha: Balance, limitPrice: Balance)
    case claimRoot(hotkey: AccountId)
}

enum SubtensorStakingOperationError: Error {
    case novaFeeUnavailable
    case unprotectedSubnetOrder
    case limitOnRootOrder
}

struct SubtensorExecutedAmounts: Equatable {
    let tao: Balance
    let alpha: Balance
    let netuid: UInt16
}

struct SubtensorStakingOperationOutcome: Equatable {
    let executed: SubtensorExecutedAmounts?
    let claimedTao: Balance?
    let novaFeePaid: Balance?
    let alphaFeePaid: Balance?
    let extrinsicHash: String?
}

enum SubtensorSellPlan: Equatable {
    case sellAll
    case partial
    case belowMinimumOut
    case remainderWouldBeSwept
    case remainderWouldBeErased
    case exceedsAvailable
}

struct SubtensorTradeQuote: Equatable {
    let quote: SubtensorQuote
    let novaFee: SubtensorNovaFee?
    let expectedOut: Balance
    let minimumOut: Balance
    let limitPrice: Balance
}
