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

extension SubtensorPositionPresenter {
    func trackOpenedIfReady() {
        guard !isOpenedTracked, let group = state.group else {
            return
        }

        if state.isRoot {
            guard state.claimable != nil || state.isClaimableFailed, state.blockNumber != nil, isHoldsResolved else {
                return
            }
        }

        isOpenedTracked = true

        trackAnalytics(
            .subtensorPositionOpened(
                target: analyticsTarget,
                netuid: AnalyticsContentValue.netuid(group.netuid),
                hasHold: state.holdRemainingBlocks != nil,
                hasLock: (state.unstakeBasis?.locked ?? 0) > 0,
                rewardsState: rewardsState
            )
        )
    }
}

private extension SubtensorPositionPresenter {
    var rewardsState: StakingRewardsState {
        guard state.isRoot else {
            return .none
        }

        if state.isClaimableFailed {
            return .unavailable
        }

        if state.claimTarget != nil {
            return .claimable
        }

        let hasBelowMinimum = state.claimable?.contains { preview in
            preview.redeemable > 0 && !SubtensorRootClaimRule.isClaimable(preview)
        } ?? false

        return hasBelowMinimum ? .belowMinimum : .none
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
