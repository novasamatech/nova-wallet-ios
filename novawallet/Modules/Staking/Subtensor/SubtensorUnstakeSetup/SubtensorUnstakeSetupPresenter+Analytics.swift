import Foundation
import NovaAnalytics

extension SubtensorUnstakeSetupPresenter: AnalyticsTracking {
    var hasLockedStake: Bool {
        guard let basis, let group else {
            return false
        }

        return basis.locked > 0 ||
            basis.positions.contains { $0.locked > 0 } ||
            basis.positions.count < group.positions.count
    }

    func createValidationReporter() -> SubtensorValidationReporter {
        SubtensorValidationReporter(
            flow: .unstake,
            stage: .setup,
            target: target?.analyticsTarget,
            walletType: selectedAccount.chainAccount.type.analyticsWalletType
        )
    }

    func trackBlockedIfNeeded() {
        guard !isBlockedTracked, let basis, let group, !group.positions.isEmpty else {
            return
        }

        let reason: StakingBlockedReason

        if holdRemainingBlocks(for: nil) != nil {
            reason = .rootHold
        } else if basis.available == 0 {
            reason = .allLocked
        } else {
            return
        }

        isBlockedTracked = true

        trackAnalytics(
            .subtensorStakingBlocked(
                flow: .unstake,
                reason: reason,
                walletType: selectedAccount.chainAccount.type.analyticsWalletType,
                target: target?.analyticsTarget
            )
        )
    }

    func trackInitiated(for model: SubtensorConfirmModel) {
        guard
            case let .unstake(unstakeModel) = model.mode,
            let group,
            let subject = chainAsset.subtensorAnalyticsSubject(for: model.target) else {
            return
        }

        let shape = UnstakeAnalyticsShape(
            mode: unstakeModel.plan.emptiesGroup(group) ? .full : .partial,
            hotkeys: CountBucket(count: group.positions.count),
            hasLocked: model.hasLockedStake,
            slippage: model.tolerance?.analyticsSlippageBucket
        )

        let taoAmount = isRoot ? unstakeModel.amount : model.acknowledgedQuote?.expectedOut

        trackAnalytics(
            .subtensorUnstakeInitiated(
                subject: subject,
                shape: shape,
                amount: chainAsset.subtensorAmountBucket(taoAmount, price: price)
            )
        )
    }
}
