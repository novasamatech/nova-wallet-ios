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

        if let mode = request.origin.analyticsStakingMode {
            trackAnalytics(.subtensorStakingFailed(subject: subject, mode: mode, failure: details))
        }
    }

    func trackSubnetDiscovery() {
        let event = stakingOption.chainAsset.chain.analyticsNetworkName.map { network in
            AnalyticsEvent.stakingFlowOpened(network: network, source: .resultDiscover)
        }

        trackAnalytics(event)
    }
}

private extension SubtensorOperationResultPresenter {
    var analyticsSubject: SubtensorAnalyticsSubject? {
        stakingOption.chainAsset.subtensorAnalyticsSubject(for: request.target)
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
    }
}
