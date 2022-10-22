import Foundation

enum ReferendumVoteConfirmError: Error {
    case locksSubscriptionFailed(_ internalError: Error)
    case submitVoteFailed(_ internalError: Error)
}
