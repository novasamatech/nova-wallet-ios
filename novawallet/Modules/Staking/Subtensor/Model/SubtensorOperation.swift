import BigInt
import Foundation

struct SubtensorNovaFee: Equatable {
    let amount: Balance
    let beneficiary: AccountId
}

enum SubtensorOperation: Equatable {
    case rootStake(hotkey: AccountId, amount: Balance)
    case rootUnstake(hotkey: AccountId, amount: Balance)
    case rootUnstakeGroup(exits: [AccountId], partials: [SubtensorUnstakeSlice])
    case subnetBuy(
        hotkey: AccountId,
        netuid: UInt16,
        grossTao: Balance,
        limitPrice: Balance,
        novaFee: SubtensorNovaFee?
    )
    case subnetSell(
        hotkey: AccountId,
        netuid: UInt16,
        alpha: Balance,
        limitPrice: Balance,
        quotedTaoOut: Balance,
        novaFee: SubtensorNovaFee?
    )
    case subnetSellGroup(
        exits: [AccountId],
        partials: [SubtensorUnstakeSlice],
        netuid: UInt16,
        limitPrice: Balance,
        quotedTaoOut: Balance,
        novaFee: SubtensorNovaFee?
    )
    case rootClaim(hotkey: AccountId)
}

extension SubtensorOperation {
    var claimHotkey: AccountId? {
        guard case let .rootClaim(hotkey) = self else {
            return nil
        }

        return hotkey
    }

    var hotkeyCount: Int {
        switch self {
        case let .rootUnstakeGroup(exits, partials), let .subnetSellGroup(exits, partials, _, _, _, _):
            Set(exits + partials.map(\.hotkey)).count
        case .rootStake, .rootUnstake, .subnetBuy, .subnetSell, .rootClaim:
            1
        }
    }

    var netuids: Set<UInt16>? {
        switch self {
        case .rootStake, .rootUnstake, .rootUnstakeGroup:
            [SubtensorPallet.rootNetuid]
        case .rootClaim:
            nil
        case let .subnetBuy(_, netuid, _, _, _),
             let .subnetSell(_, netuid, _, _, _, _),
             let .subnetSellGroup(_, _, netuid, _, _, _):
            [netuid]
        }
    }
}

enum SubtensorOperationError: Error, Equatable {
    case novaFeeUnavailable
    case unprotectedSubnetOrder
    case limitOnRootOrder
    case invalidHotkeyGroup
}

extension SubtensorOperationError: ErrorContentConvertible {
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

struct SubtensorOperationOutcome: Equatable {
    let executed: SubtensorExecutedAmounts?
    let novaFeePaid: Balance?
    let alphaFeePaid: Balance?
    let networkFeePaid: Balance?
    let extrinsicHash: ExtrinsicHash
    let blockHash: BlockHash
}

struct SubtensorSubmissionFailure: Error {
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

struct SubtensorQuoteArgs: Equatable {
    enum Direction: Equatable {
        case stake(taoIn: Balance)
        case unstake(alphaIn: Balance)
    }

    let netuid: UInt16
    let direction: Direction
}

enum SubtensorQuoteError: Error, Equatable {
    case missingSpotPrice(netuid: UInt16)
    case quoteUnavailable(netuid: UInt16)
}

struct SubtensorQuote: Equatable {
    let args: SubtensorQuoteArgs
    let sim: SubtensorPallet.SimSwapResult
    let spotPrice: Balance
    let feeRate: UInt16
}

extension SubtensorQuote {
    var expectedOut: Balance {
        switch args.direction {
        case .stake:
            return sim.alphaAmount
        case .unstake:
            return sim.taoAmount
        }
    }

    var poolFee: Balance {
        switch args.direction {
        case .stake:
            return sim.taoFee
        case .unstake:
            return sim.alphaFee
        }
    }

    /// pool-move component only: the sim amounts are net of the input-side fee, so the fee
    /// never double-counts into the impact
    var priceImpact: BigRational? {
        guard let postTradePrice else {
            return nil
        }

        let move = postTradePrice > spotPrice ? postTradePrice - spotPrice : spotPrice - postTradePrice

        return BigRational(numerator: move, denominator: spotPrice)
    }

    var postTradePrice: Balance? {
        guard sim.alphaAmount > 0, spotPrice > 0 else {
            return nil
        }

        let scaledTao = sim.taoAmount * SubtensorPallet.alphaPriceScale

        switch args.direction {
        case .stake:
            let averagePrice = Self.divideRoundingUp(scaledTao, by: sim.alphaAmount)

            return Self.divideRoundingUp(averagePrice * averagePrice, by: spotPrice)
        case .unstake:
            let averagePrice = scaledTao / sim.alphaAmount

            return averagePrice * averagePrice / spotPrice
        }
    }
}

private extension SubtensorQuote {
    static func divideRoundingUp(_ dividend: Balance, by divisor: Balance) -> Balance {
        (dividend + divisor - 1) / divisor
    }
}

struct SubtensorTradeQuote: Equatable {
    let quote: SubtensorQuote
    let amountIn: Balance
    let novaFee: SubtensorNovaFee?
    let novaFeeRate: BigRational
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
