import Foundation
import NovaAnalytics

final class SubtensorDataAnalytics: AnalyticsTracking {
    let screen: BittensorScreen

    private var reportedEndpoints: Set<BittensorDataEndpoint> = []

    init(screen: BittensorScreen) {
        self.screen = screen
    }

    func trackFailure(_ error: Error?, endpoint: BittensorDataEndpoint) {
        guard
            let error,
            let reason = error.bittensorDataFailureReason,
            !reportedEndpoints.contains(endpoint) else {
            return
        }

        reportedEndpoints.insert(endpoint)

        trackAnalytics(
            .bittensorDataFailed(
                endpoint: endpoint,
                reason: reason,
                screen: screen,
                retryable: (error as? BittensorApiError)?.allowsUserRetry ?? true
            )
        )
    }

    func trackFailure(_ error: SubtensorBaseError) {
        switch error {
        case let .feeFailed(underlying), let .quoteFailed(underlying):
            trackFailure(underlying, endpoint: error.isNovaFeeUnavailable ? .novaUtilsConfig : .chainRpc)
        case let .preflightFailed(underlying),
             let .rootHoldsFailed(underlying),
             let .existentialDepositFailed(underlying):
            trackFailure(underlying, endpoint: .chainRpc)
        }
    }
}

private extension Error {
    var bittensorDataFailureReason: BittensorDataFailureReason? {
        if let apiError = self as? BittensorApiError {
            switch apiError {
            case .deviceBound:
                return nil
            case .rejected:
                return .rejected
            case .unavailable:
                return .serverError
            case .generationStale:
                return .generationStale
            case .contractViolation:
                return .contractViolation
            case .transport:
                return .transport
            }
        }

        return (self as NSError).domain == NSURLErrorDomain ? .transport : .serverError
    }
}
