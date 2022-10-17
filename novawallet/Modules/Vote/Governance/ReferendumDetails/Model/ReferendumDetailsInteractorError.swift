import Foundation

enum ReferendumDetailsInteractorError: Error {
    case referendumFailed(_ internalError: Error)
    case actionDetailsFailed(_ internalError: Error)
    case accountVotesFailed(_ internalError: Error)
    case metadataFailed(_ internalError: Error)
    case identitiesFailed(_ internalError: Error)
    case priceFailed(_ internalError: Error)
    case blockNumberFailed(_ internalError: Error)
    case blockTimeFailed(_ internalError: Error)
}
