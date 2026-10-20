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

    func createValidationReporter() -> SubtensorValidationReporter {
        SubtensorValidationReporter(
            flow: .claim,
            stage: .confirm,
            target: .root,
            walletType: model.account.chainAccount.type.analyticsWalletType
        )
    }

    func trackBlocked(_ reason: StakingBlockedReason) {
        trackAnalytics(
            .subtensorStakingBlocked(
                flow: .claim,
                reason: reason,
                walletType: model.account.chainAccount.type.analyticsWalletType,
                target: .root
            )
        )
    }

    func trackWatchOnlyIfNeeded() {
        guard isWatchOnly else {
            return
        }

        trackBlocked(.watchOnly)
    }
}
