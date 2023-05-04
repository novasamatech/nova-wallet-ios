enum BaseReferendumsInteractorError: Error {
    case settingsLoadFailed
    case blockTimeFetchFailed(_ internalError: Error)
    case blockTimeServiceFailed(_ internalError: Error)
    case referendumsFetchFailed(_ internalError: Error)
    case votingSubscriptionFailed(_ internalError: Error)
    case offchainVotingFetchFailed(_ internalError: Error)
    case metadataSubscriptionFailed(_ internalError: Error)
    case blockNumberSubscriptionFailed(_ internalError: Error)
}
