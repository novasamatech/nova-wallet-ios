import Foundation

enum SubtensorOperationResultConstants {
    static let confirmationCap: TimeInterval = 90

    static func confirmationCap(for route: SubtensorSubmissionRoute, blockTime: BlockTime) -> TimeInterval {
        guard route == .shielded else {
            return confirmationCap
        }

        let shieldWindow = TimeInterval(blockTime * SubtensorShieldConstants.confirmationWindowBlocks).seconds

        return max(confirmationCap, shieldWindow)
    }
}

enum SubtensorOperationResultState {
    case progress
    case done(outcome: SubtensorOperationOutcome, time: Date)
    case failed(failure: SubtensorSubmissionFailure, time: Date, holdRemaining: TimeInterval?)
    case unconfirmed(time: Date)

    var acceptsSubmissionResult: Bool {
        switch self {
        case .progress, .unconfirmed:
            true
        case .done, .failed:
            false
        }
    }
}

enum SubtensorResultAction: Equatable {
    case done
    case tryAgain
    case close
    case viewPosition
    case discoverSubnets
    case yourBittensor
    case backToPosition
}

enum SubtensorResultInfoRow: Equatable {
    case swapRate
    case costBasis
    case slippage
    case validator
    case networkFee
}

extension SubtensorSubmissionFailure {
    var isSigningCancelled: Bool {
        guard stage == .notSubmitted else {
            return false
        }

        return error.isSigningCancelled || (error as? SigningWrapperError) == .pinCheckNotPassed
    }

    var isSigningRefused: Bool {
        guard stage == .notSubmitted else {
            return false
        }

        return error.isSigningClosed || error.isWatchOnlySigning || error.notSupportedSignerType != nil
    }

    var isRetryable: Bool {
        if error is SubtensorOperationError {
            return false
        }

        switch error as? SubtensorSubmissionError {
        case .subnetNotExists,
             .subtokenDisabled,
             .hotkeyNotRegistered,
             .coldkeySwapInProgress,
             .safeModeActive,
             .tooManyStakingHotkeys,
             .rootClaimTooHeavy:
            return false
        default:
            return true
        }
    }
}

extension SubtensorOperation {
    var tradeDirection: SubtensorTradeDirection? {
        switch self {
        case .subnetBuy:
            .buy
        case .subnetSell, .subnetSellGroup:
            .sell
        case .rootStake, .rootUnstake, .rootUnstakeGroup, .rootClaim:
            nil
        }
    }

    var rootHotkeys: [AccountId] {
        switch self {
        case let .rootStake(hotkey, _), let .rootUnstake(hotkey, _), let .rootClaim(hotkey):
            [hotkey]
        case let .rootUnstakeGroup(exits, partials):
            exits + partials.map(\.hotkey)
        case .subnetBuy, .subnetSell, .subnetSellGroup:
            []
        }
    }
}
