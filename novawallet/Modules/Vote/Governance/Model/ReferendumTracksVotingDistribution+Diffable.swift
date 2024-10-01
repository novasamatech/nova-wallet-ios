import Foundation
import BigInt

extension ReferendumTracksVotingDistribution {
    func hasDiff(from other: Self) -> Bool {
        let totalLockedSelf = totalLocked()
        let totalLockedOther = other.totalLocked()

        if totalLockedSelf != totalLockedOther {
            return true
        }

        let totalDelegatedSelf = totalDelegated() ?? 0
        let totalDelegatedOther = other.totalDelegated() ?? 0

        if totalDelegatedSelf != totalDelegatedOther {
            return true
        }

        if trackLocks.count != other.trackLocks.count {
            return true
        } else {
            for (index, lock) in trackLocks.enumerated() {
                let otherLock = other.trackLocks[index]

                if lock.amount != otherLock.amount {
                    return true
                }
            }
        }

        return votes.hasDiff(from: other.votes)
    }
}

extension ReferendumAccountVotingDistribution {
    func hasDiff(from other: Self) -> Bool {
        if votes.count != other.votes.count {
            return true
        } else {
            for (id, vote) in votes {
                if let otherVote = other.votes[id], vote != otherVote {
                    return true
                }
            }
        }

        if delegatings.count != other.delegatings.count {
            return true
        } else {
            for (trackId, delegating) in delegatings {
                if
                    let otherDelegating = other.delegatings[trackId],
                    delegating.balance != otherDelegating.balance {
                    return true
                }
            }
        }

        return false
    }
}
