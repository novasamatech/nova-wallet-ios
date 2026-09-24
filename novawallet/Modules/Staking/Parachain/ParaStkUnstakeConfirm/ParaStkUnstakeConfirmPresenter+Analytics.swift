import Foundation
import NovaAnalytics

extension ParaStkUnstakeConfirmPresenter: AnalyticsTracking {
    func trackUnstakeEvent(
        _ makeEvent: (StakingAnalyticsType, AnalyticsContentValue, Decimal, Decimal?) -> AnalyticsEvent
    ) {
        let event = chainAsset.chain.analyticsNetworkName.map { network in
            makeEvent(stakingType, network, unstakingAmount(), price?.analyticsRate)
        }

        trackAnalytics(event)
    }

    func trackUnstakeFailure(for error: Error) {
        let event = chainAsset.chain.analyticsNetworkName.map { network in
            AnalyticsEvent.unstakeFailed(
                type: stakingType,
                network: network,
                reason: error.analyticsTransactionFailureReason
            )
        }

        trackAnalytics(event)
    }
}
