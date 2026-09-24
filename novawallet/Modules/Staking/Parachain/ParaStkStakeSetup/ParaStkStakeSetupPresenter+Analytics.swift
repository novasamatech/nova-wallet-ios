import Foundation
import NovaAnalytics

extension ParaStkStakeSetupPresenter: AnalyticsTracking {
    func trackStakingInitiated(amount: Decimal) {
        guard isStartStakingFlow else {
            return
        }

        let event = chainAsset.chain.analyticsNetworkName.map { network in
            AnalyticsEvent.stakingInitiated(
                type: stakingType,
                network: network,
                amount: amount,
                rate: price?.analyticsRate
            )
        }

        trackAnalytics(event)
    }
}
