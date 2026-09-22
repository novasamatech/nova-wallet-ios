import Foundation
import NovaAnalytics

extension MythosStkUnstakeConfirmPresenter: AnalyticsTracking {
    func trackUnstakeEvent(
        _ makeEvent: (StakingAnalyticsType, AnalyticsContentValue, Decimal, Decimal?) -> AnalyticsEvent
    ) {
        guard let submittedAmount else {
            return
        }

        let event = chainAsset.chain.analyticsNetworkName.map { network in
            makeEvent(
                stakingType,
                network,
                submittedAmount.decimal(assetInfo: chainAsset.assetDisplayInfo),
                price?.analyticsRate
            )
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
