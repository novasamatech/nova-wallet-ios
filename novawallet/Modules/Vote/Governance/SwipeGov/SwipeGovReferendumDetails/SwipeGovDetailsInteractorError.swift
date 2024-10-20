enum SwipeGovDetailsInteractorError: Error {
    case referendumFailed(_ internalError: Error)
    case actionDetailsFailed(_ internalError: Error)
    case metadataFailed(_ internalError: Error)
    case identitiesFailed(_ internalError: Error)
    case blockNumberFailed(_ internalError: Error)
    case blockTimeFailed(_ internalError: Error)
}
