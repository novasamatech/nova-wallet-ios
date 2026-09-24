import Foundation
import NovaAnalytics

extension StakingUnbondConfirmPresenter: AnalyticsTracking {
    func trackUnstakeEvent(
        _ makeEvent: (StakingAnalyticsType, AnalyticsContentValue, Decimal, Decimal?) -> AnalyticsEvent
    ) {
        let event = chain.analyticsNetworkName.map { network in
            makeEvent(stakingType, network, inputAmount, priceData?.analyticsRate)
        }

        trackAnalytics(event)
    }

    func trackUnstakeFailure(for error: Error) {
        let event = chain.analyticsNetworkName.map { network in
            AnalyticsEvent.unstakeFailed(
                type: stakingType,
                network: network,
                reason: error.analyticsTransactionFailureReason
            )
        }

        trackAnalytics(event)
    }
}
