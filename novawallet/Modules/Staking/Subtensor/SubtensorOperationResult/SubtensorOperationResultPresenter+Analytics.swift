import Foundation
import NovaAnalytics

extension SubtensorOperationResultPresenter: AnalyticsTracking {
    func trackSuccess(_ outcome: SubtensorOperationOutcome) {
        trackCompletion(.done, executed: outcome.executed)
    }

    func trackUnconfirmed() {
        trackCompletion(.unconfirmed, executed: nil)
    }

    func trackFailure(_ failure: SubtensorSubmissionFailure) {
        guard let details = failure.analyticsDetails(for: request.origin.analyticsFlow) else {
            trackUnconfirmed()
            return
        }

        guard !isOutcomeTracked, let subject = analyticsSubject else {
            return
        }

        isOutcomeTracked = true

        switch request.origin {
        case .newPosition, .addStake, .buyMore:
            if let mode = request.origin.analyticsStakingMode {
                trackAnalytics(.subtensorStakingFailed(subject: subject, mode: mode, failure: details))
            }
        case .unstake, .sell:
            trackAnalytics(.subtensorUnstakeFailed(subject: subject, shape: unstakeShape, failure: details))
        case .claim:
            trackAnalytics(.rewardsClaimFailed(network: subject.network, failure: details))
        }
    }

    func trackAction(_ action: SubtensorResultAction) {
        trackAnalytics(
            .subtensorResultAction(
                analyticsAction(for: action),
                flow: request.origin.analyticsFlow,
                target: request.analyticsTarget
            )
        )
    }

    func trackSubnetDiscovery() {
        let event = stakingOption.chainAsset.chain.analyticsNetworkName.map { network in
            AnalyticsEvent.stakingFlowOpened(network: network, source: .resultDiscover)
        }

        trackAnalytics(event)
    }
}

private extension SubtensorOperationResultPresenter {
    func analyticsAction(for action: SubtensorResultAction) -> StakingResultAction {
        switch action {
        case .done:
            request.origin == .newPosition || request.emptiesPosition ? .yourBittensor : .close
        case .tryAgain:
            .tryAgain
        case .close:
            .close
        case .viewPosition:
            .viewPosition
        case .discoverSubnets:
            .discoverSubnets
        case .yourBittensor:
            .yourBittensor
        case .backToPosition:
            .backToPosition
        }
    }

    var analyticsSubject: SubtensorAnalyticsSubject? {
        stakingOption.chainAsset.subtensorAnalyticsSubject(for: request.target)
    }

    var unstakeShape: UnstakeAnalyticsShape {
        UnstakeAnalyticsShape(
            mode: request.emptiesPosition ? .full : .partial,
            hotkeys: request.groupHotkeyCount > 0 ? CountBucket(count: request.groupHotkeyCount) : nil,
            hasLocked: request.hasLockedStake,
            slippage: request.slippage?.analyticsSlippageBucket
        )
    }

    func trackCompletion(_ outcome: StakingCompletionOutcome, executed: SubtensorExecutedAmounts?) {
        guard !isOutcomeTracked, let subject = analyticsSubject else {
            return
        }

        isOutcomeTracked = true

        let duration = DurationBucket(duration: Date().timeIntervalSince(progressStartedAt))
        let amount = stakingOption.chainAsset.subtensorAmountBucket(
            request.analyticsTaoAmount(executed: executed),
            price: request.prices.taoPrice
        )

        switch request.origin {
        case .newPosition, .addStake, .buyMore:
            if let mode = request.origin.analyticsStakingMode {
                trackAnalytics(
                    .subtensorStakingCompleted(
                        subject: subject,
                        mode: mode,
                        outcome: outcome,
                        duration: duration,
                        amount: amount
                    )
                )
            }
        case .unstake, .sell:
            trackAnalytics(
                .subtensorUnstakeCompleted(
                    subject: subject,
                    shape: unstakeShape,
                    outcome: outcome,
                    duration: duration,
                    amount: amount
                )
            )
        case .claim where outcome == .done:
            trackAnalytics(
                .rewardsClaimCompleted(
                    network: subject.network,
                    amount: amount,
                    duration: duration,
                    claimedZero: executed.map { $0.tao == 0 }
                )
            )
        case .claim:
            break
        }
    }
}
