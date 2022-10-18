import Foundation

enum ReferendumVoteInteractorError: Error {
    case assetBalanceFailed(_ internalError: Error)
    case priceFailed(_ internalError: Error)
    case votingReferendumFailed(_ internalError: Error)
    case feeFailed(_ internalError: Error)
}
