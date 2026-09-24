import Foundation
import NovaAnalytics

extension ParaStkStakeConfirmPresenter: AnalyticsTracking {
    func trackStakingEvent(
        _ makeEvent: (StakingAnalyticsType, AnalyticsContentValue, Decimal, Decimal?) -> AnalyticsEvent
    ) {
        guard isStartStakingFlow else {
            return
        }

        let event = chainAsset.chain.analyticsNetworkName.map { network in
            makeEvent(stakingType, network, amount, price?.analyticsRate)
        }

        trackAnalytics(event)
    }

    func trackStakingFailure(for error: Error) {
        guard isStartStakingFlow else {
            return
        }

        let event = chainAsset.chain.analyticsNetworkName.map { network in
            AnalyticsEvent.stakingFailed(
                type: stakingType,
                network: network,
                reason: error.analyticsTransactionFailureReason
            )
        }

        trackAnalytics(event)
    }
}
