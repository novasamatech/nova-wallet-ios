import Foundation
import NovaAnalytics

extension SubtensorStakeSetupPresenter: AnalyticsTracking {
    func trackScreenOpened() {
        guard rootEntryPresentation == .quickPickRoot else {
            return
        }

        trackTypeSelected(.root, method: .quickPickRoot)
    }

    func trackQuickPickSelected(_ target: SubtensorStakeTarget, order: SubtensorQuickPickOrder) {
        guard let method = order.analyticsSelectionMethod else {
            return
        }

        trackTypeSelected(target, method: method)
    }

    func resetAnalytics() {
        isValidatorPicked = false

        let isNewPosition = mode.origin == .newPosition
        let analyticsTarget = target?.analyticsTarget

        abandonTracker.makeEvent = {
            isNewPosition ? AnalyticsEvent.subtensorStakingAbandoned(stage: .setup, target: analyticsTarget) : nil
        }
    }

    func trackInitiated(for model: SubtensorConfirmModel) {
        abandonTracker.markProceeded()

        guard
            let mode = model.origin.analyticsStakingMode,
            let subject = chainAsset.subtensorAnalyticsSubject(for: model.target) else {
            return
        }

        trackAnalytics(
            .subtensorStakingInitiated(
                subject: subject,
                mode: mode,
                validatorSource: validatorSource(for: model),
                slippage: model.tolerance?.analyticsSlippageBucket,
                amount: chainAsset.subtensorAmountBucket(model.amount, price: price)
            )
        )
    }
}

private extension SubtensorStakeSetupPresenter {
    func trackTypeSelected(_ target: SubtensorStakeTarget, method: StakingAnalyticsSelectionMethod) {
        let event = chainAsset.subtensorAnalyticsSubject(for: target).map { subject in
            AnalyticsEvent.subtensorTypeSelected(subject: subject, method: method, netuid: target.analyticsNetuid)
        }

        trackAnalytics(event)
    }

    func validatorSource(for model: SubtensorConfirmModel) -> StakingValidatorSource {
        if mode.isLocked || model.validator.hotkey == existingPrimaryHotkey(on: model.target.netuid) {
            return .existingHotkey
        }

        return isValidatorPicked ? .manual : .recommended
    }
}

private extension SubtensorQuickPickOrder {
    var analyticsSelectionMethod: StakingAnalyticsSelectionMethod? {
        switch self {
        case .poolSize: .quickPickPoolSize
        case .age: .quickPickAge
        case .apy: .quickPickApy
        case .root: nil
        }
    }
}
