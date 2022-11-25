import Foundation
import BigInt

/**
 * Given the information about Voting (priors + active votes), statuses of referenda and track locks
 * Constructs the estimated claiming schedule.
 * The schedule is exact when all involved referenda are completed. Only ongoing referenda' end time is estimateted
 *
 * The claiming schedule shows how much tokens will be unlocked and when.
 * Schedule may consist of zero or more [GovernanceUnlockSchedule.Item] with corresponding actions to do.
 *
 * The algorithm itself consists of several parts
 *
 * 1. Determine individual unlocks
 * This step is based on prior [ConvictionVoting.PriorLock], [ConvictionVoting.AccountVote],
 * [ConvictionVoting.Delegating]
 * a. Each non-zero prior (both from casting and delegating) has a single individual unlock
 * b. Each non-zero vote has a single individual unlock.
 *    However, unlock time for votes is at least unlock time of corresponding prior.
 * c. Find a gap between [voting] and [trackLocks], which indicates an extra claimable amount
 *    To provide additive effect of gap, we add total voting lock on top of it:
 *    if [voting] has some pending locks - they gonna delay their amount but always leaving
 *    trackGap untouched & claimable.
 *    On the other hand, if other tracks have locks bigger than [voting]'s total lock,
 *    trackGap will be partially or full delayed by them
 *
 * During this step we also determine the set of [GovernanceUnlockSchedule.Action]
 *
 * 2. Combine all locks with the same unlock time into single lock
 *  a. Result's amount is the maximum between combined locks
 *  b. Result's affects is a concatenation of all affects from combined locks
 *
 * 3. Construct preliminary unlock schedule based on the following algorithm
 *   a. Sort pairs from step (2) by descending [GovernanceUnlockSchedule.Item.unlockAt] order;
 *   b. For each item in the sorted list, find the difference between the biggest currently
 *   processed lock and item's amount;
 *   c. Since we start from the most far locks in the future, finding a positive difference means that
 *   this difference is actually an entry in desired unlock schedule. Negative difference means that this unlock is
 *   completely covered by future's unlock with bigger amount.
 *   Thus, we should discard it from the schedule and move its affects to the currently known maximum lock
 *   in order to not to loose its actions when unlocking maximum lock.
 *
 * 4. To find which unlocks are claimable one should call [GovernanceUnlockSchedule.availableItem(at:)]
 * function by providing current block number;
 */
final class GovUnlocksCalculator {
    private func createUnlocksFromVotes(
        _ votes: [ReferendumIdLocal: ReferendumAccountVoteLocal],
        referendums: [ReferendumIdLocal: GovUnlockReferendumProtocol],
        tracks: [ReferendumIdLocal: TrackIdLocal],
        additionalInfo: GovUnlockCalculationInfo
    ) -> [TrackIdLocal: [GovernanceUnlockSchedule.Item]] {
        let initial = [TrackIdLocal: [GovernanceUnlockSchedule.Item]]()

        return votes.reduce(into: initial) { accum, voteKeyValue in
            let referendumId = voteKeyValue.key
            let vote = voteKeyValue.value

            guard let referendum = referendums[referendumId], let trackId = tracks[referendumId] else {
                return
            }

            do {
                let unlockAt = try referendum.estimateVoteLockingPeriod(
                    for: vote,
                    additionalInfo: additionalInfo
                ) ?? 0

                let unvoteAction = GovernanceUnlockSchedule.Action.unvote(track: trackId, index: referendumId)
                let unlockAction = GovernanceUnlockSchedule.Action.unlock(track: trackId)

                let unlock = GovernanceUnlockSchedule.Item(
                    amount: vote.totalBalance,
                    unlockAt: unlockAt,
                    actions: [unvoteAction, unlockAction]
                )

                accum[trackId] = (accum[trackId] ?? []) + [unlock]
            } catch {
                return
            }
        }
    }

    private func createUnlockFromPrior(
        _ prior: ConvictionVoting.PriorLock,
        trackId: TrackIdLocal
    ) -> GovernanceUnlockSchedule.Item {
        let priorUnlockAction = GovernanceUnlockSchedule.Action.unlock(track: trackId)

        return GovernanceUnlockSchedule.Item(
            amount: prior.amount,
            unlockAt: prior.unlockAt,
            actions: [priorUnlockAction]
        )
    }

    private func extendUnlocksForVotesWithPriors(
        _ unlocks: [TrackIdLocal: [GovernanceUnlockSchedule.Item]],
        priors: [TrackIdLocal: ConvictionVoting.PriorLock]
    ) -> [TrackIdLocal: [GovernanceUnlockSchedule.Item]] {
        priors.reduce(into: unlocks) { accum, keyValue in
            let trackId = keyValue.key
            let priorLock = keyValue.value

            guard priorLock.exists else {
                return
            }

            /// one can't unlock voted amount if there is a prior in the track that unlocks later
            let items: [GovernanceUnlockSchedule.Item] = (unlocks[trackId] ?? []).map { unlock in
                if priorLock.unlockAt > unlock.unlockAt {
                    return GovernanceUnlockSchedule.Item(
                        amount: unlock.amount,
                        unlockAt: priorLock.unlockAt,
                        actions: unlock.actions
                    )
                } else {
                    return unlock
                }
            }

            /// also add a prior unlock separately
            let priorUnlock = createUnlockFromPrior(priorLock, trackId: trackId)

            accum[trackId] = items + [priorUnlock]
        }
    }

    private func extendUnlocksWithDelegatingPriors(
        _ unlocks: [TrackIdLocal: [GovernanceUnlockSchedule.Item]],
        delegations: [TrackIdLocal: ReferendumDelegatingLocal]
    ) -> [TrackIdLocal: [GovernanceUnlockSchedule.Item]] {
        delegations.reduce(into: unlocks) { accum, keyValue in
            let trackId = keyValue.key
            let priorLock = keyValue.value.prior

            guard priorLock.exists else {
                return
            }

            let priorUnlock = createUnlockFromPrior(priorLock, trackId: trackId)

            /// one can either vote directly or delegate
            accum[trackId] = [priorUnlock]
        }
    }

    private func extendUnlocksWithFreeTracksLocks(
        _ tracksVoting: ReferendumTracksVotingDistribution,
        unlocks: [TrackIdLocal: [GovernanceUnlockSchedule.Item]]
    ) -> [TrackIdLocal: [GovernanceUnlockSchedule.Item]] {
        tracksVoting.trackLocks.reduce(into: unlocks) { accum, trackLock in
            let trackId = TrackIdLocal(trackLock.trackId)
            let trackLockAmount = trackLock.amount

            let neededLockAmount = tracksVoting.votes.lockedBalance(for: trackId)

            if trackLockAmount > neededLockAmount {
                let priorUnlockAction = GovernanceUnlockSchedule.Action.unlock(track: trackId)

                let unlock = GovernanceUnlockSchedule.Item(
                    amount: trackLockAmount,
                    unlockAt: 0,
                    actions: [priorUnlockAction]
                )

                accum[trackId] = (accum[trackId] ?? []) + [unlock]
            }
        }
    }

    private func createVotingUnlocks(
        for tracksVoting: ReferendumTracksVotingDistribution,
        referendums: [ReferendumIdLocal: GovUnlockReferendumProtocol],
        additionalInfo: GovUnlockCalculationInfo
    ) -> [TrackIdLocal: [GovernanceUnlockSchedule.Item]] {
        let tracks = tracksVoting.votes.tracksByReferendums()

        let voteUnlocksByTrack = createUnlocksFromVotes(
            tracksVoting.votes.votes,
            referendums: referendums,
            tracks: tracks,
            additionalInfo: additionalInfo
        )

        let voteUnlocksWithPriors = extendUnlocksForVotesWithPriors(
            voteUnlocksByTrack,
            priors: tracksVoting.votes.priorLocks
        )

        let unlocksFromVotesAndDelegatings = extendUnlocksWithDelegatingPriors(
            voteUnlocksWithPriors,
            delegations: tracksVoting.votes.delegatings
        )

        return extendUnlocksWithFreeTracksLocks(tracksVoting, unlocks: unlocksFromVotesAndDelegatings)
    }

    private func flattenUnlocksByBlockNumber(
        from unlocks: [TrackIdLocal: [GovernanceUnlockSchedule.Item]]
    ) -> [GovernanceUnlockSchedule.Item] {
        let initial = [BlockNumber: GovernanceUnlockSchedule.Item]()

        let unlocksByBlockNumber = unlocks.reduce(into: initial) { accum, keyValue in
            let trackUnlocks = keyValue.value

            for unlock in trackUnlocks {
                if let prevUnlock = accum[unlock.unlockAt] {
                    accum[unlock.unlockAt] = .init(
                        amount: max(unlock.amount, prevUnlock.amount),
                        unlockAt: unlock.unlockAt,
                        actions: prevUnlock.actions.union(unlock.actions)
                    )
                } else {
                    accum[unlock.unlockAt] = unlock
                }
            }
        }

        return Array(unlocksByBlockNumber.values)
    }

    private func normalizeUnlocks(_ unlocks: [GovernanceUnlockSchedule.Item]) -> [GovernanceUnlockSchedule.Item] {
        var sortedByBlockNumber = unlocks.sorted(by: { $0.unlockAt > $1.unlockAt })

        var optMaxUnlock: (BigUInt, Int)?
        for (index, unlock) in sortedByBlockNumber.enumerated() {
            if let maxUnlock = optMaxUnlock {
                let maxAmount = maxUnlock.0
                let maxIndex = maxUnlock.1

                if unlock.amount > maxAmount {
                    /// new max unlock found
                    optMaxUnlock = (unlock.amount, index)

                    /// only part of the amount can be unlocked
                    sortedByBlockNumber[index] = .init(
                        amount: unlock.amount - maxAmount,
                        unlockAt: unlock.unlockAt,
                        actions: unlock.actions
                    )
                } else {
                    /// this unlock can't happen so move actions to future unlock
                    let prevUnlock = sortedByBlockNumber[maxIndex]
                    sortedByBlockNumber[maxIndex] = .init(
                        amount: prevUnlock.amount,
                        unlockAt: prevUnlock.unlockAt,
                        actions: prevUnlock.actions.union(unlock.actions)
                    )

                    sortedByBlockNumber[index] = .init(amount: 0, unlockAt: unlock.unlockAt, actions: [])
                }

            } else {
                optMaxUnlock = (unlock.amount, index)
            }
        }

        return Array(sortedByBlockNumber.reversed().filter { !$0.isEmpty })
    }

    private func createSchedule(
        from unlocks: [TrackIdLocal: [GovernanceUnlockSchedule.Item]]
    ) -> GovernanceUnlockSchedule {
        let flattenedByBlockNumber = flattenUnlocksByBlockNumber(from: unlocks)
        let items = normalizeUnlocks(flattenedByBlockNumber)

        return .init(items: items)
    }
}

extension GovUnlocksCalculator: GovernanceUnlockCalculatorProtocol {
    func createUnlocksSchedule(
        for tracksVoting: ReferendumTracksVotingDistribution,
        referendums: [ReferendumIdLocal: GovUnlockReferendumProtocol],
        additionalInfo: GovUnlockCalculationInfo
    ) -> GovernanceUnlockSchedule {
        let unlocks = createVotingUnlocks(
            for: tracksVoting,
            referendums: referendums,
            additionalInfo: additionalInfo
        )

        return createSchedule(from: unlocks)
    }
}
