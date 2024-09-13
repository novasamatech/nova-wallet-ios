import Operation_iOS

enum ReferendumFilter {
    struct VoteAvailable {
        let referendums: [ReferendumLocal]
        let accountVotes: ReferendumAccountVotingDistribution?

        func callAsFunction() -> [ReferendumLocal] {
            referendums.filter {
                guard let trackId = $0.trackId else {
                    return false
                }

                return $0.canVote
                    && (accountVotes?.votes[$0.index] == nil)
                    && (accountVotes?.delegatings[trackId] == nil)
            }
        }
    }
}
