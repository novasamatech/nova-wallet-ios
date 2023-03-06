import Foundation

enum GovernanceYourDelegationsInteractorError: Error {
    case delegationsSubscriptionFailed(Error)
    case delegatesFetchFailed(Error)
    case blockSubscriptionFailed(Error)
    case blockTimeFetchFailed(Error)
    case tracksFetchFailed(Error)
    case metadataSubscriptionFailed(Error)
}
