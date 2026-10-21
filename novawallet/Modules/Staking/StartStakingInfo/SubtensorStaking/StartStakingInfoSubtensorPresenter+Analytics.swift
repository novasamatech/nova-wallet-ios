import Foundation
import NovaAnalytics

extension StartStakingInfoSubtensorPresenter {
    func setupAbandonEvent() {
        abandonTracker.makeEvent = {
            AnalyticsEvent.subtensorStakingAbandoned(stage: .landing, target: nil)
        }
    }

    func trackGateRefusal(_ reason: StakingBlockedReason, wallet: MetaAccountModel) {
        abandonTracker.markProceeded()

        trackAnalytics(
            .subtensorStakingBlocked(
                flow: .stake,
                reason: reason,
                walletType: wallet.type.analyticsWalletType,
                target: nil
            )
        )
    }
}
