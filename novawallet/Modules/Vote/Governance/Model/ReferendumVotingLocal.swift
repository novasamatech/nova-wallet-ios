import Foundation

struct ReferendumAccountVotingDistribution {
    let votes: [ReferendumIdLocal: ReferendumAccountVoteLocal]
    let delegatings: [TrackIdLocal: ReferendumDelegatingLocal]

    func addingVote(
        _ vote: ReferendumAccountVoteLocal,
        referendumId: ReferendumIdLocal
    ) -> ReferendumAccountVotingDistribution {
        var newVotes = votes
        newVotes[referendumId] = vote

        return ReferendumAccountVotingDistribution(
            votes: newVotes,
            delegatings: delegatings
        )
    }

    func addingDelegating(
        _ delegating: ReferendumDelegatingLocal,
        trackId: TrackIdLocal
    ) -> ReferendumAccountVotingDistribution {
        var newDelegatings = delegatings
        newDelegatings[trackId] = delegating

        return ReferendumAccountVotingDistribution(
            votes: votes,
            delegatings: newDelegatings
        )
    }
}

struct ReferendumTracksVotingDistribution {
    let votes: ReferendumAccountVotingDistribution
    let trackLocks: [ConvictionVoting.ClassLock]
}
