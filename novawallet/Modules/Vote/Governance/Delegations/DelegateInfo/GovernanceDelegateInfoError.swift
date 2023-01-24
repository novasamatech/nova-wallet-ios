import Foundation

enum GovernanceDelegateInfoError: Error {
    case detailsFetchFailed(Error)
    case metadataSubscriptionFailed(Error)
    case identityFetchFailed(Error)
    case blockSubscriptionFailed(Error)
    case blockTimeFetchFailed(Error)
}
