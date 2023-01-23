import Foundation
import BigInt

struct ReferendumAccountVotingDistribution {
    let votes: [ReferendumIdLocal: ReferendumAccountVoteLocal]
    let votedTracks: [TrackIdLocal: Set<ReferendumIdLocal>]
    let delegatings: [TrackIdLocal: ReferendumDelegatingLocal]
    let priorLocks: [TrackIdLocal: ConvictionVoting.PriorLock]
    let maxVotesPerTrack: UInt32

    init(
        votes: [ReferendumIdLocal: ReferendumAccountVoteLocal] = [:],
        votedTracks: [TrackIdLocal: Set<ReferendumIdLocal>] = [:],
        delegatings: [TrackIdLocal: ReferendumDelegatingLocal] = [:],
        priorLocks: [TrackIdLocal: ConvictionVoting.PriorLock] = [:],
        maxVotesPerTrack: UInt32
    ) {
        self.votes = votes
        self.votedTracks = votedTracks
        self.delegatings = delegatings
        self.priorLocks = priorLocks
        self.maxVotesPerTrack = maxVotesPerTrack
    }

    func tracksByReferendums() -> [ReferendumIdLocal: TrackIdLocal] {
        let initial = [ReferendumIdLocal: TrackIdLocal]()

        return votedTracks.reduce(into: initial) { accum, keyValue in
            let trackId = keyValue.key

            for referendumId in keyValue.value {
                accum[referendumId] = trackId
            }
        }
    }

    func lockedBalance(for trackId: TrackIdLocal) -> BigUInt {
        if let delegating = delegatings[trackId] {
            return max(delegating.balance, delegating.prior.amount)
        } else {
            let maxVotedBalance = (votedTracks[trackId] ?? []).map { referendumId in
                votes[referendumId]?.totalBalance ?? 0
            }
            .max() ?? 0

            let priorLockedBalance = priorLocks[trackId]?.amount ?? 0

            return max(maxVotedBalance, priorLockedBalance)
        }
    }

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
            priorLocks: priorLocks,
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
            priorLocks: priorLocks,
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
            priorLocks: priorLocks,
            maxVotesPerTrack: maxVotesPerTrack
        )
    }

    func addingPriorLock(
        _ priorLock: ConvictionVoting.PriorLock,
        track: TrackIdLocal
    ) -> ReferendumAccountVotingDistribution {
        var newPriorLocks = priorLocks
        newPriorLocks[track] = priorLock

        return ReferendumAccountVotingDistribution(
            votes: votes,
            votedTracks: votedTracks,
            delegatings: delegatings,
            priorLocks: newPriorLocks,
            maxVotesPerTrack: maxVotesPerTrack
        )
    }
}

struct ReferendumTracksVotingDistribution {
    let votes: ReferendumAccountVotingDistribution
    let trackLocks: [ConvictionVoting.ClassLock]

    func totalLocked() -> BigUInt {
        trackLocks.reduce(BigUInt(0)) { max($0, $1.amount) }
    }

    func totalDelegated() -> BigUInt? {
        guard !votes.delegatings.isEmpty else {
            return nil
        }

        return votes.delegatings.reduce(BigUInt(0)) { total, keyValue in
            max(total, keyValue.value.balance)
        }
    }
}
