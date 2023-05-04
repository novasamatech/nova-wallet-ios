import Foundation

enum ReferendumsInteractorError: Error {
    case priceSubscriptionFailed(_ internalError: Error)
    case balanceSubscriptionFailed(_ internalError: Error)
    case chainSaveFailed(_ internalError: Error)
    case unlockScheduleFetchFailed(_ internalError: Error)
}
