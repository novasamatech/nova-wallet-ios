import Foundation
import NovaAnalytics

extension RampPresenter: AnalyticsTracking {
    func trackFlowOpened() {
        if case .onRamp = rampAction.type {
            trackFeatureOpened(.buy)
        }

        trackAnalytics(initiatedEvent())
    }

    func trackFlowCompleted(for actionType: RampActionType) {
        guard !didTrackCompletion else {
            return
        }

        didTrackCompletion = true

        trackAnalytics(completedEvent(for: actionType))
    }

    func initiatedEvent() -> AnalyticsEvent? {
        guard let analyticsContent else {
            return nil
        }

        let event: AnalyticsEvent = switch rampAction.type {
        case .onRamp:
            .buyInitiated(
                provider: analyticsContent.provider,
                asset: analyticsContent.asset,
                network: analyticsContent.network
            )
        case .offRamp:
            .sellInitiated(
                provider: analyticsContent.provider,
                asset: analyticsContent.asset,
                network: analyticsContent.network
            )
        }

        return event
    }

    func completedEvent(for actionType: RampActionType) -> AnalyticsEvent? {
        guard let analyticsContent else {
            return nil
        }

        let event: AnalyticsEvent = switch actionType {
        case .onRamp:
            .buyCompleted(
                provider: analyticsContent.provider,
                asset: analyticsContent.asset,
                network: analyticsContent.network
            )
        case .offRamp:
            .sellCompleted(
                provider: analyticsContent.provider,
                asset: analyticsContent.asset,
                network: analyticsContent.network
            )
        }

        return event
    }
}
