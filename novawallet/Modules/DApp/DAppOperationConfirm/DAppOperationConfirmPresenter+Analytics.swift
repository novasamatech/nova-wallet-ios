import Foundation
import NovaAnalytics

extension DAppOperationConfirmPresenter: AnalyticsTracking {
    func trackSignRequestShown() {
        guard let signAnalyticsContext else {
            return
        }

        trackAnalytics(
            .signRequestShown(
                source: signAnalyticsContext.source,
                method: signAnalyticsContext.method,
                chain: signAnalyticsContext.chain
            )
        )
    }

    func trackSignOutcome(for responseResult: Result<DAppOperationResponse, Error>) {
        guard let signAnalyticsContext, !didTrackSignOutcome else {
            return
        }

        didTrackSignOutcome = true

        trackAnalytics(
            signOutcomeEvent(for: responseResult, context: signAnalyticsContext)
        )
    }

    func signOutcomeEvent(
        for responseResult: Result<DAppOperationResponse, Error>,
        context: DAppSignAnalyticsContext
    ) -> AnalyticsEvent {
        switch responseResult {
        case let .success(response):
            return response.signature != nil
                ? .signApproved(
                    source: context.source,
                    method: context.method,
                    chain: context.chain
                )
                : .signRejected(
                    source: context.source,
                    method: context.method,
                    chain: context.chain
                )
        case .failure:
            return .signFailed(
                source: context.source,
                method: context.method,
                chain: context.chain,
                reason: .signingFailed
            )
        }
    }
}
