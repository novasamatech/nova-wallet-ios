import Foundation

enum GovernanceRemoveVotesInteractorError: Error {
    case votesSubsctiptionFailed(Error)
    case feeFetchFailed(Error)
    case removeVotesFailed(Error)
    case balanceSubscriptionFailed(Error)
}
