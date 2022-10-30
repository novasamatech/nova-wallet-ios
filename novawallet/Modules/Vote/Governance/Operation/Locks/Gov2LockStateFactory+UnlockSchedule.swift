import Foundation
import RobinHood
import BigInt

extension Gov2LockStateFactory {
    private func createUnlocksFromVotes(
        _ votes: [ReferendumIdLocal: ReferendumAccountVoteLocal],
        referendums: [ReferendumIdLocal: ReferendumInfo],
        tracks: [ReferendumIdLocal: TrackIdLocal],
        additionalInfo: AdditionalInfo
    ) -> [TrackIdLocal: [GovernanceUnlockSchedule.Item]] {
        let initial = [TrackIdLocal: [GovernanceUnlockSchedule.Item]]()

        return votes.reduce(into: initial) { accum, voteKeyValue in
            let referendumId = voteKeyValue.key
            let vote = voteKeyValue.value

            guard let referendum = referendums[referendumId], let trackId = tracks[referendumId] else {
                return
            }

            do {
                let unlockAt = try estimateVoteLockingPeriod(
                    for: referendum,
                    accountVote: vote,
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
                let freeAmount = trackLockAmount - neededLockAmount

                let priorUnlockAction = GovernanceUnlockSchedule.Action.unlock(track: trackId)

                let unlock = GovernanceUnlockSchedule.Item(
                    amount: freeAmount,
                    unlockAt: 0,
                    actions: [priorUnlockAction]
                )

                accum[trackId] = (accum[trackId] ?? []) + [unlock]
            }
        }
    }

    private func createVotingUnlocks(
        for tracksVoting: ReferendumTracksVotingDistribution,
        referendums: [ReferendumIdLocal: ReferendumInfo],
        additionalInfo: AdditionalInfo
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

    func createScheduleOperation(
        dependingOn referendumsOperation: BaseOperation<[ReferendumIdLocal: ReferendumInfo]>,
        additionalInfoOperation: BaseOperation<AdditionalInfo>,
        tracksVoting: ReferendumTracksVotingDistribution
    ) -> BaseOperation<GovernanceUnlockSchedule> {
        ClosureOperation<GovernanceUnlockSchedule> {
            let referendums = try referendumsOperation.extractNoCancellableResultData()
            let additions = try additionalInfoOperation.extractNoCancellableResultData()

            let unlocks = self.createVotingUnlocks(
                for: tracksVoting,
                referendums: referendums,
                additionalInfo: additions
            )

            return self.createSchedule(from: unlocks)
        }
    }
}
