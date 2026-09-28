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
    var isFillable: Bool {
        isFillable(atLimit: limitPrice)
    }

    func isFillable(atLimit limit: Balance) -> Bool {
        let sim = quote.sim
        let spotPrice = quote.spotPrice

        guard sim.alphaAmount > 0, spotPrice > 0 else {
            return false
        }

        let scaledTao = sim.taoAmount * SubtensorStakingPallet.alphaPriceScale

        switch quote.args.direction {
        case .stake:
            let averagePrice = Self.divideRoundingUp(scaledTao, by: sim.alphaAmount)
            let postTradePrice = Self.divideRoundingUp(averagePrice * averagePrice, by: spotPrice)

            return postTradePrice < limit
        case .unstake:
            let averagePrice = scaledTao / sim.alphaAmount
            let postTradePrice = averagePrice * averagePrice / spotPrice

            return postTradePrice > limit
        }
    }
}

private extension SubtensorTradeQuote {
    static func divideRoundingUp(_ dividend: Balance, by divisor: Balance) -> Balance {
        (dividend + divisor - 1) / divisor
    }
}
