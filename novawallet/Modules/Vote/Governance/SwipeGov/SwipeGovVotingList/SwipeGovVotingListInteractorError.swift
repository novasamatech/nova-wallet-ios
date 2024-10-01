enum SwipeGovVotingListInteractorError: Error {
    case assetBalanceFailed(_ internalError: Error)
    case metadataFailed(_ internalError: Error)
    case votingBasket(_ internalError: Error)
}
