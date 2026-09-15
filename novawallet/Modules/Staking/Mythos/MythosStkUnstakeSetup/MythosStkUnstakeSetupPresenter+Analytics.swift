import Foundation
import NovaAnalytics

extension MythosStkUnstakeSetupPresenter: AnalyticsTracking {
    func trackUnstakeInitiated() {
        let event = chainAsset.chain.analyticsNetworkName.map { network in
            AnalyticsEvent.unstakeInitiated(
                type: stakingType,
                network: network,
                amount: decimalStakingAmount(),
                rate: price?.analyticsRate
            )
        }

        trackAnalytics(event)
    }
}
