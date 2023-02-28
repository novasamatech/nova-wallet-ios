import Foundation

enum GovernanceDelegateInteractorError: Error {
    case assetBalanceFailed(_ internalError: Error)
    case priceFailed(_ internalError: Error)
    case feeFailed(_ internalError: Error)
    case accountVotesFailed(_ internalError: Error)
    case blockNumberSubscriptionFailed(_ internalError: Error)
    case blockTimeFailed(_ internalError: Error)
    case stateDiffFailed(_ internalError: Error)
}
