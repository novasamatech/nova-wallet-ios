import Operation_iOS

enum ReferendumFilter {
    struct VoteAvailable {
        let referendums: [ReferendumIdLocal: ReferendumLocal]
        let accountVotes: ReferendumAccountVotingDistribution?

        func callAsFunction() -> [ReferendumIdLocal: ReferendumLocal] {
            referendums.filter { key, value in
                guard let trackId = value.trackId else {
                    return false
                }

                return value.canVote
                    && (accountVotes?.votes[key] == nil)
                    && (accountVotes?.delegatings[trackId] == nil)
            }
        }
    }
}
