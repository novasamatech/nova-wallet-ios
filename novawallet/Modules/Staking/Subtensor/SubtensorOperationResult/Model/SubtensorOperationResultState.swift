import Foundation

enum SubtensorOperationResultConstants {
    static let confirmationCap: TimeInterval = 90
}

enum SubtensorOperationResultState {
    case progress
    case done(outcome: SubtensorStakingOperationOutcome, time: Date)
    case failed(failure: SubtensorStakingSubmissionFailure, time: Date, holdRemaining: TimeInterval?)
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

extension SubtensorStakingSubmissionFailure {
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
        if error is SubtensorStakingOperationError {
            return false
        }

        switch error as? SubtensorStakingSubmissionError {
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

extension SubtensorStakingOperation {
    var tradeDirection: SubtensorTradeDirection? {
        switch self {
        case .subnetBuy:
            .buy
        case .subnetSell, .subnetSellAll:
            .sell
        case .rootStake, .rootUnstake, .rootUnstakeAll, .rootClaim:
            nil
        }
    }

    var rootHotkeys: [AccountId] {
        switch self {
        case let .rootStake(hotkey, _), let .rootUnstake(hotkey, _), let .rootClaim(hotkey):
            [hotkey]
        case let .rootUnstakeAll(hotkeys):
            hotkeys
        case .subnetBuy, .subnetSell, .subnetSellAll:
            []
        }
    }
}
