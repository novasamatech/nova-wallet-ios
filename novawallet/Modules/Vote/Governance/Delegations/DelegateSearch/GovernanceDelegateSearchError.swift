import Foundation

enum GovernanceDelegateSearchError: Error {
    case delegateFetchFailed(Error)
    case identityFetchFailed(AccountId, Error)
    case metadataSubscriptionFailed(Error)
    case blockSubscriptionFailed(_ internalError: Error)
}
