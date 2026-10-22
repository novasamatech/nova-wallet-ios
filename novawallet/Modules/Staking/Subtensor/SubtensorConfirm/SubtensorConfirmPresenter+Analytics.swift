import Foundation
import NovaAnalytics

final class SubtensorConfirmAnalytics {
    enum PriceMoveBanner {
        case shown
        case acknowledged
    }

    let abandonTracker = AnalyticsAbandonTracker { nil }
    let data = SubtensorDataAnalytics(screen: .confirm)
    let reporter: SubtensorValidationReporter
    private(set) var priceMoveBanner: PriceMoveBanner?

    init(model: SubtensorConfirmModel) {
        reporter = SubtensorValidationReporter(
            flow: model.origin.analyticsFlow,
            stage: .confirm,
            target: model.target.analyticsTarget,
            walletType: model.account.chainAccount.type.analyticsWalletType
        )
    }

    deinit {
        switch priceMoveBanner {
        case .shown:
            reporter.report(.priceMoved, outcome: .cancelled)
        case .acknowledged:
            reporter.report(.priceMoved, outcome: .blocked)
        case .none:
            break
        }
    }

    func beginTap() {
        if priceMoveBanner == .acknowledged {
            closePriceMoveBanner(.blocked)
        }
    }

    func syncPriceMoveBanner(isShown: Bool) {
        switch (priceMoveBanner, isShown) {
        case (.none, true):
            priceMoveBanner = .shown
        case (.acknowledged, true):
            closePriceMoveBanner(.blocked)
            priceMoveBanner = .shown
        case (.shown, false):
            closePriceMoveBanner(.cancelled)
        case (.shown, true), (.acknowledged, false), (.none, false):
            break
        }
    }

    func acknowledgePriceMove() {
        priceMoveBanner = .acknowledged
    }

    func takePriceMoveAcknowledgement() -> Bool {
        guard priceMoveBanner == .acknowledged else {
            return false
        }

        closePriceMoveBanner(.proceeded)

        return true
    }

    private func closePriceMoveBanner(_ outcome: StakingValidationOutcome) {
        priceMoveBanner = nil
        reporter.report(.priceMoved, outcome: outcome)
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
