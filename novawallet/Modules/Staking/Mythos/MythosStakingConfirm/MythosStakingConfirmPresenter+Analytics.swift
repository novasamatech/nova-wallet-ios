import Foundation
import NovaAnalytics

extension MythosStakingConfirmPresenter: AnalyticsTracking {
    func updateAbandonEvent() {
        let isStartStakingFlow = stakingDetails == nil

        abandonTracker.makeEvent = {
            isStartStakingFlow ? AnalyticsEvent.stakingAbandoned(stage: .confirm) : nil
        }
    }

    func trackStakingEvent(
        _ makeEvent: (StakingAnalyticsType, AnalyticsContentValue, Decimal, Decimal?) -> AnalyticsEvent
    ) {
        guard isStartStakingSubmission else {
            return
        }

        let event = chainAsset.chain.analyticsNetworkName.map { network in
            makeEvent(
                stakingType,
                network,
                model.amount.toStake.decimal(assetInfo: chainAsset.assetDisplayInfo),
                price?.analyticsRate
            )
        }

        trackAnalytics(event)
    }

    func trackStakingFailure(for error: Error) {
        guard isStartStakingSubmission else {
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
