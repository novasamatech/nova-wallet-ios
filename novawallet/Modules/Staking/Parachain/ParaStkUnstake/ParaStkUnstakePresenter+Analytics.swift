import Foundation
import NovaAnalytics

extension ParaStkUnstakePresenter: AnalyticsTracking {
    func trackUnstakeInitiated(amount: Decimal) {
        let event = chainAsset.chain.analyticsNetworkName.map { network in
            AnalyticsEvent.unstakeInitiated(
                type: stakingType,
                network: network,
                amount: amount,
                rate: price?.analyticsRate
            )
        }

        trackAnalytics(event)
    }
}
