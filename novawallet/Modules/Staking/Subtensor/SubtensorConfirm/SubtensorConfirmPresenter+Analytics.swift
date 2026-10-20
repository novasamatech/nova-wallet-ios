import Foundation
import NovaAnalytics

final class SubtensorConfirmAnalytics {
    let abandonTracker = AnalyticsAbandonTracker { nil }
    let data = SubtensorDataAnalytics(screen: .confirm)
    let reporter: SubtensorValidationReporter
    private(set) var isPriceMoveAcknowledged = false

    init(model: SubtensorConfirmModel) {
        reporter = SubtensorValidationReporter(
            flow: model.origin.analyticsFlow,
            stage: .confirm,
            target: model.target.analyticsTarget,
            walletType: model.account.chainAccount.type.analyticsWalletType
        )
    }

    func beginTap() {
        isPriceMoveAcknowledged = false
    }

    func acknowledgePriceMove() {
        isPriceMoveAcknowledged = true
        reporter.proceeded()
    }

    func takePriceMoveAcknowledgement() -> Bool {
        defer {
            isPriceMoveAcknowledged = false
        }

        return isPriceMoveAcknowledged
    }
}

extension SubtensorConfirmPresenter: AnalyticsTracking {
    func trackScreenOpened() {
        let isNewPosition = model.origin == .newPosition
        let target = model.target.analyticsTarget

        analytics.abandonTracker.makeEvent = {
            isNewPosition ? AnalyticsEvent.subtensorStakingAbandoned(stage: .confirm, target: target) : nil
        }

        guard isWatchOnly else {
            return
        }

        analytics.abandonTracker.markProceeded()

        trackAnalytics(
            .subtensorStakingBlocked(
                flow: model.origin.analyticsFlow,
                reason: .watchOnly,
                walletType: model.account.chainAccount.type.analyticsWalletType,
                target: target
            )
        )
    }

    func createValidationReporter() -> SubtensorValidationReporter {
        SubtensorValidationReporter(
            flow: model.origin.analyticsFlow,
            stage: .confirm,
            target: model.target.analyticsTarget,
            walletType: model.account.chainAccount.type.analyticsWalletType
        )
    }

    func trackConfirmed() {
        analytics.abandonTracker.markProceeded()

        let priceMoved = analytics.takePriceMoveAcknowledgement()

        guard
            let mode = model.origin.analyticsStakingMode,
            let subject = chainAsset.subtensorAnalyticsSubject(for: model.target) else {
            return
        }

        trackAnalytics(
            .subtensorStakingConfirmed(
                subject: subject,
                mode: mode,
                priceMoved: priceMoved,
                amount: chainAsset.subtensorAmountBucket(model.amount, price: price)
            )
        )
    }
}
