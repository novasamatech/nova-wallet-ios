import Foundation

enum ReferendumVoteSetupInteractorError: Error {
    case accountVotesFailed(_ internalError: Error)
    case blockNumberSubscriptionFailed(_ internalError: Error)
    case blockTimeFailed(_ internalError: Error)
    case stateDiffFailed(_ internalError: Error)
}
