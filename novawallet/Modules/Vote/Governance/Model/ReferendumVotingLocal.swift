import Foundation

struct ReferendumAccountVotingDistribution {
    let votes: [ReferendumIdLocal: ReferendumAccountVoteLocal]
    let votedTracks: [TrackIdLocal: Set<ReferendumIdLocal>]
    let delegatings: [TrackIdLocal: ReferendumDelegatingLocal]
    let maxVotesPerTrack: UInt32

    func addingVote(
        _ vote: ReferendumAccountVoteLocal,
        referendumId: ReferendumIdLocal
    ) -> ReferendumAccountVotingDistribution {
        var newVotes = votes
        newVotes[referendumId] = vote

        return ReferendumAccountVotingDistribution(
            votes: newVotes,
            votedTracks: votedTracks,
            delegatings: delegatings,
            maxVotesPerTrack: maxVotesPerTrack
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
            votedTracks: votedTracks,
            delegatings: newDelegatings,
            maxVotesPerTrack: maxVotesPerTrack
        )
    }

    func addingReferendum(
        _ referendumIndex: ReferendumIdLocal,
        track: TrackIdLocal
    ) -> ReferendumAccountVotingDistribution {
        var newVotedTracks = votedTracks
        var referendums = newVotedTracks[track] ?? Set()
        referendums.insert(referendumIndex)
        newVotedTracks[track] = referendums

        return ReferendumAccountVotingDistribution(
            votes: votes,
            votedTracks: newVotedTracks,
            delegatings: delegatings,
            maxVotesPerTrack: maxVotesPerTrack
        )
    }
}

struct ReferendumTracksVotingDistribution {
    let votes: ReferendumAccountVotingDistribution
    let trackLocks: [ConvictionVoting.ClassLock]
}
