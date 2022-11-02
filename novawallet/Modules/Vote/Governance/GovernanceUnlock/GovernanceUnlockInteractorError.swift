import Foundation

enum GovernanceUnlockInteractorError: Error {
    case votingSubscriptionFailed(_ internalError: Error)
    case unlockScheduleFetchFailed(_ internalError: Error)
    case priceSubscriptionFailed(_ internalError: Error)
    case blockNumberSubscriptionFailed(_ internalError: Error)
    case blockTimeFetchFailed(_ internalError: Error)
}
