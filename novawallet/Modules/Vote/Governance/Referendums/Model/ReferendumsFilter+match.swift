extension ReferendumsFilter {
    func match(
        _ referendum: ReferendumLocal,
        voting: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>?,
        offchainVoting: GovernanceOffchainVotesLocal?
    ) -> Bool {
        switch self {
        case .all:
            return true
        case .notVoted:
            if voting?.value?.votes.votes[referendum.index] != nil {
                return false
            } else if offchainVoting?.fetchVotes(for: referendum.index) != nil {
                return false
            }

            return true
        case .voted:
            if voting?.value?.votes.votes[referendum.index] != nil {
                return true
            } else if offchainVoting?.fetchVotes(for: referendum.index) != nil {
                return true
            }

            return false
        }
    }
}
