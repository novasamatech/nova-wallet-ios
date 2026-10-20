import Foundation
import NovaAnalytics

extension SubtensorConfirmPresenter: AnalyticsTracking {
    func trackScreenOpened() {
        let isNewPosition = model.origin == .newPosition
        let target = model.target.analyticsTarget

        abandonTracker.makeEvent = {
            isNewPosition ? AnalyticsEvent.subtensorStakingAbandoned(stage: .confirm, target: target) : nil
        }
    }

    func trackConfirmed() {
        abandonTracker.markProceeded()

        let priceMoved = isPriceMoveAcknowledged
        isPriceMoveAcknowledged = false

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
