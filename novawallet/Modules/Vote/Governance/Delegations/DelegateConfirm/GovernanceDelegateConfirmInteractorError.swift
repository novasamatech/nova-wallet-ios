import Foundation

enum GovernanceDelegateConfirmInteractorError: Error {
    case locksSubscriptionFailed(_ internalError: Error)
    case submitFailed(_ internalError: Error)
}
