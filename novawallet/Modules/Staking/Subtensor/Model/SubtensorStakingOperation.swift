import Foundation

struct SubtensorNovaFee: Equatable {
    let amount: Balance
    let beneficiary: AccountId
}

enum SubtensorStakingOperation: Equatable {
    case rootStake(hotkey: AccountId, amount: Balance)
    case rootUnstake(hotkey: AccountId, amount: Balance)
    case rootUnstakeAll(hotkeys: [AccountId])
    case subnetBuy(hotkey: AccountId, netuid: UInt16, grossTao: Balance, limitPrice: Balance)
    case subnetSell(hotkey: AccountId, netuid: UInt16, alpha: Balance, limitPrice: Balance, quotedTaoOut: Balance)
    case subnetSellAll(hotkeys: [AccountId], netuid: UInt16, limitPrice: Balance, quotedTaoOut: Balance)
}

enum SubtensorStakingOperationError: Error, Equatable {
    case novaFeeUnavailable
    case unprotectedSubnetOrder
    case limitOnRootOrder
    case invalidHotkeyGroup
}

extension SubtensorStakingOperationError: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        let message: String = switch self {
        case .novaFeeUnavailable:
            strings.stakingSubtensorErrorNovaFeeUnavailable()
        case .unprotectedSubnetOrder, .limitOnRootOrder, .invalidHotkeyGroup:
            strings.commonUndefinedErrorMessage()
        }

        return ErrorContent(title: strings.operationErrorTitle(), message: message)
    }
}

struct SubtensorExecutedAmounts: Equatable {
    let tao: Balance
    let alpha: Balance
    let netuid: UInt16
}

struct SubtensorStakingOperationOutcome: Equatable {
    let executed: SubtensorExecutedAmounts?
    let novaFeePaid: Balance?
    let alphaFeePaid: Balance?
    let networkFeePaid: Balance?
    let extrinsicHash: ExtrinsicHash
    let blockHash: BlockHash
}

struct SubtensorStakingSubmissionFailure: Error {
    enum Stage: Equatable {
        case notSubmitted
        case dispatched(blockHash: BlockHash, extrinsicHash: ExtrinsicHash)
        case unconfirmed(extrinsicHash: ExtrinsicHash?)
    }

    let stage: Stage
    let error: Error
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
    let amountIn: Balance
    let novaFee: SubtensorNovaFee?
    let expectedOut: Balance
    let swapMinimumOut: Balance
    let minimumOut: Balance
    let limitPrice: Balance
}

extension SubtensorTradeQuote {
    func isFillable(atLimit limit: Balance) -> Bool {
        guard let postTradePrice = quote.postTradePrice else {
            return false
        }

        switch quote.args.direction {
        case .stake:
            return postTradePrice < limit
        case .unstake:
            return postTradePrice > limit
        }
    }

    func tighterLimit(than limit: Balance) -> Balance {
        switch quote.args.direction {
        case .stake:
            return min(limitPrice, limit)
        case .unstake:
            return max(limitPrice, limit)
        }
    }
}
