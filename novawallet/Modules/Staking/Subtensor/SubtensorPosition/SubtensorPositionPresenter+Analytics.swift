import Foundation
import NovaAnalytics

extension SubtensorPositionPresenter: AnalyticsTracking {
    var analyticsTarget: StakingAnalyticsTarget {
        state.isRoot ? .root : .subnet
    }

    func trackActionRefusal(
        _ action: SubtensorPositionAction,
        reason: StakingBlockedReason,
        wallet: MetaAccountModel
    ) {
        trackAnalytics(
            .subtensorStakingBlocked(
                flow: action.analyticsFlow,
                reason: reason,
                walletType: wallet.type.analyticsWalletType,
                target: analyticsTarget
            )
        )
    }
}

private extension SubtensorPositionAction {
    var analyticsFlow: StakingFlow {
        switch self {
        case .claim: .claim
        case .addStake, .buy: .stake
        case .unstake, .sell: .unstake
        }
    }
}
