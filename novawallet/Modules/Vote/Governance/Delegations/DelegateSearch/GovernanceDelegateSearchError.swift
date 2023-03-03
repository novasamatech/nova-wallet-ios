import Foundation

enum GovernanceDelegateSearchError: Error {
    case delegateFetchFailed(Error)
    case identityFetchFailed(AccountId, Error)
    case metadataSubscriptionFailed(Error)
}
