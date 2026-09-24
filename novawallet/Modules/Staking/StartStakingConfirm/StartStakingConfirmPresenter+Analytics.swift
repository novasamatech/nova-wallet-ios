import Foundation
import NovaAnalytics

extension StartStakingConfirmPresenter: AnalyticsTracking {
    func trackStakingEvent(
        _ makeEvent: (StakingAnalyticsType, AnalyticsContentValue, Decimal, Decimal?) -> AnalyticsEvent
    ) {
        guard let stakingOption = stakingOption() else {
            return
        }

        let event = chainAsset.chain.analyticsNetworkName.map { network in
            makeEvent(stakingOption.analyticsType, network, amount, price?.analyticsRate)
        }

        trackAnalytics(event)
    }

    func trackStakingFailure(for error: Error) {
        guard let stakingOption = stakingOption() else {
            return
        }

        let event = chainAsset.chain.analyticsNetworkName.map { network in
            AnalyticsEvent.stakingFailed(
                type: stakingOption.analyticsType,
                network: network,
                reason: error.analyticsTransactionFailureReason
            )
        }

        trackAnalytics(event)
    }
}
