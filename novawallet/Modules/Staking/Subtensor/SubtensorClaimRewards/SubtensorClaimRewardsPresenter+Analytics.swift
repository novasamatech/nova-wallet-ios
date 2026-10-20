import Foundation
import NovaAnalytics

extension SubtensorClaimRewardsPresenter: AnalyticsTracking {
    func trackInitiatedIfReady() {
        guard
            !isInitiatedTracked,
            isPriceResolved,
            claimable != nil || isPositionsSyncFailed,
            !isWatchOnly,
            !isNothingToClaim,
            let network = chainAsset.chain.analyticsNetworkName else {
            return
        }

        isInitiatedTracked = true

        let otherClaimable = claimable.map { SubtensorRootClaimRule.otherClaimableCount(in: $0, target: hotkey) } ?? 0

        trackAnalytics(
            .rewardsClaimInitiated(
                network: network,
                amount: chainAsset.subtensorAmountBucket(shownPreview.redeemable, price: price),
                validators: CountBucket(count: otherClaimable + 1)
            )
        )
    }
}
