import Foundation

enum AddDelegationInteractorError: Error {
    case blockSubscriptionFailed(_ internalError: Error)
    case blockTimeFetchFailed(_ internalError: Error)
    case delegateListFetchFailed(_ internalError: Error)
}
