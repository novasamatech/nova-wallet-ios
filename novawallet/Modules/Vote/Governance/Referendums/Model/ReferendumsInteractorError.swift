import Foundation

enum ReferendumsInteractorError: Error {
    case settingsLoadFailed
    case priceSubscriptionFailed(_ internalError: Error)
    case balanceSubscriptionFailed(_ internalError: Error)
    case chainSaveFailed(_ internalError: Error)
    case referendumsFetchFailed(_ internalError: Error)
    case blockNumberSubscriptionFailed(_ internalError: Error)
    case metadataSubscriptionFailed(_ internalError: Error)
    case votingSubscriptionFailed(_ internalError: Error)
    case blockTimeFetchFailed(_ internalError: Error)
    case blockTimeServiceFailed(_ internalError: Error)
    case unlockScheduleFetchFailed(_ internalError: Error)
    case delegationMetadataSubscriptionFailed(_ internalError: Error)
    case offchainVotingFetchFailed(_ internalError: Error)
}
