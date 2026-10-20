import Foundation
import NovaAnalytics

extension ChainAsset {
    func subtensorAnalyticsSubject(for target: SubtensorStakeTarget) -> SubtensorAnalyticsSubject? {
        analyticsNetworkName.map { SubtensorAnalyticsSubject(network: $0, target: target.analyticsTarget) }
    }

    func subtensorAmountBucket(_ amount: Balance?, price: PriceData?) -> AmountBucket? {
        amount.flatMap { AmountBucket(amount: $0.decimal(assetInfo: assetDisplayInfo), rate: price?.analyticsRate) }
    }
}

extension BigRational {
    var analyticsSlippageBucket: SlippageBucket? {
        decimalValue.map { SlippageBucket(percent: $0 * 100) }
    }
}

extension SubtensorOperationOrigin {
    var analyticsStakingMode: StakingMode? {
        switch self {
        case .newPosition: .newPosition
        case .addStake: .addStake
        case .buyMore: .buyMore
        case .unstake, .sell, .claim: nil
        }
    }

    var analyticsFlow: StakingFlow {
        switch self {
        case .newPosition, .addStake, .buyMore: .stake
        case .unstake, .sell: .unstake
        case .claim: .claim
        }
    }
}

extension SubtensorSubmissionFailure {
    func analyticsDetails(for flow: StakingFlow) -> StakingFailureDetails? {
        let analyticsStage: StakingFailureStage

        switch stage {
        case .notSubmitted:
            analyticsStage = .notSubmitted
        case .dispatched:
            analyticsStage = .dispatched
        case .unconfirmed:
            return nil
        }

        return StakingFailureDetails(
            reason: analyticsReason(for: flow),
            stage: analyticsStage,
            retryable: isSigningCancelled || isRetryable
        )
    }

    private func analyticsReason(for flow: StakingFlow) -> TransactionFailureReason {
        if isSigningCancelled || error.isSigningClosed {
            return .userCancelled
        }

        if let reason = (error as? SubtensorSubmissionError)?.analyticsReason(for: flow) {
            return reason
        }

        if (error as NSError).domain == NSURLErrorDomain {
            return .networkError
        }

        return stage == .notSubmitted ? .notSubmitted : .dispatchOther
    }
}

private extension SubtensorSubmissionError {
    func analyticsReason(for flow: StakingFlow) -> TransactionFailureReason? {
        switch self {
        case .priceLimitExceeded, .slippageTooHigh:
            .slippageExceeded
        case .rootStakeLocked:
            .rootStakeLocked
        case .subnetNotExists, .subtokenDisabled, .hotkeyNotRegistered, .coldkeySwapInProgress, .safeModeActive:
            .chainCondition
        case .rootClaimTooHeavy:
            .tooHeavy
        case .notEnoughBalanceToStake, .feeUnpayable:
            flow == .claim ? .fundUnavailable : nil
        case .amountTooLow:
            flow == .claim ? .belowMinimum : nil
        case .stakeUnavailable, .insufficientLiquidity, .temporarilyUnavailable, .notEnoughStakeToWithdraw,
             .tooManyStakingHotkeys, .shieldedNotExecuted:
            nil
        }
    }
}

extension SubtensorOperationResultRequest {
    var analyticsTarget: StakingAnalyticsTarget {
        target.analyticsTarget
    }

    func analyticsTaoAmount(executed: SubtensorExecutedAmounts?) -> Balance? {
        switch origin {
        case .newPosition, .addStake, .buyMore, .unstake:
            payAmount
        case .sell:
            executed?.tao ?? quote?.expectedOut
        case .claim:
            executed?.tao ?? payAmount
        }
    }
}
