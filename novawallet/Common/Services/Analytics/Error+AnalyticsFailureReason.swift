import Foundation
import SubstrateSdk
import NovaAnalytics

extension Error {
    var analyticsTransactionFailureReason: TransactionFailureReason {
        if isAnalyticsUserCancellation {
            return .userCancelled
        }

        if isAnalyticsNetworkFailure {
            return .networkError
        }

        return .unknown
    }

    var analyticsSwapFailureReason: SwapFailureReason {
        if isAnalyticsUserCancellation {
            return .userCancelled
        }

        if isAnalyticsNetworkFailure {
            return .networkError
        }

        if self is DispatchCallError {
            return .executionReverted
        }

        return .unknown
    }
}

private extension Error {
    var isAnalyticsUserCancellation: Bool {
        isSigningCancelled || isSigningClosed
    }

    var isAnalyticsNetworkFailure: Bool {
        (self as NSError).domain == NSURLErrorDomain
    }
}
