import Foundation

enum GovernanceUnlockConfirmInteractorError {
    case locksSubscriptionFailed(_ internalError: Error)
    case balanceSubscriptionFailed(_ internalError: Error)
    case feeFetchFailed(_ internalError: Error)
    case unlockFailed(_ internalError: Error)
}
