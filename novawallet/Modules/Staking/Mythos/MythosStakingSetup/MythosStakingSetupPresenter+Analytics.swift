import Foundation
import NovaAnalytics

extension MythosStakingSetupPresenter: AnalyticsTracking {
    func updateAbandonEvent() {
        let isStartStakingFlow = stakingDetails == nil

        abandonTracker.makeEvent = {
            isStartStakingFlow ? AnalyticsEvent.stakingAbandoned(stage: .setup) : nil
        }
    }

    func trackStakingInitiated(for stakingModel: MythosStakeModel) {
        guard stakingDetails == nil else {
            return
        }

        let event = chainAsset.chain.analyticsNetworkName.map { network in
            AnalyticsEvent.stakingInitiated(
                type: stakingType,
                network: network,
                amount: stakingModel.amount.toStake.decimal(assetInfo: chainAsset.assetDisplayInfo),
                rate: price?.analyticsRate
            )
        }

        trackAnalytics(event)
    }
}
