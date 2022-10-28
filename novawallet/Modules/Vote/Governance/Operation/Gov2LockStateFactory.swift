import Foundation
import RobinHood
import SubstrateSdk
import BigInt

/**
 *  Class that calculates:
 *  Locked amount diff - maximum amount of tokens locked before vote is applied and after
 *  Locked period diff - period of time needed to unlock all the tokens before vote is applied and after.
 *
 *  Locked amount calculation assumes that no unlocks can happen during voting (event if voting for the same referendum).
 *  So the diff may not decrease.
 *
 *  Locked period is calculated first by maximizing estimation for unlock block of votes (only nonzero amount).
 *  And then maximizing result between maximum period for votes and prior locks
 *  (taking into account both casting votes and delegations).
 *
 *  Note that locked period calculation uses an estimation that takes maximum time when voting for particular referendum
 *  may end.
 */

final class Gov2LockStateFactory {
    struct AdditionalInfo {
        let tracks: [Referenda.TrackId: Referenda.TrackInfo]
        let undecidingTimeout: Moment
        let voteLockingPeriod: Moment
    }

    let requestFactory: StorageRequestFactoryProtocol

    init(requestFactory: StorageRequestFactoryProtocol) {
        self.requestFactory = requestFactory
    }

    private func createReferendumsWrapper(
        for referendumIds: Set<ReferendumIdLocal>,
        connection: JSONRPCEngine,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        blockHash: Data?
    ) -> CompoundOperationWrapper<[ReferendumIdLocal: ReferendumInfo]> {
        let remoteIndexes = Array(referendumIds.map { StringScaleMapper(value: $0) })

        let wrapper: CompoundOperationWrapper<[StorageResponse<ReferendumInfo>]> = requestFactory.queryItems(
            engine: connection,
            keyParams: { remoteIndexes },
            factory: { try codingFactoryOperation.extractNoCancellableResultData() },
            storagePath: Referenda.referendumInfo,
            at: blockHash
        )

        let mappingOperation = ClosureOperation<[ReferendumIdLocal: ReferendumInfo]> {
            let responses = try wrapper.targetOperation.extractNoCancellableResultData()

            return zip(remoteIndexes, responses).reduce(into: [ReferendumIdLocal: ReferendumInfo]()) { accum, pair in
                accum[pair.0.value] = pair.1.value
            }
        }

        mappingOperation.addDependency(wrapper.targetOperation)

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: wrapper.allOperations)
    }

    private func createAdditionalInfoWrapper(
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<AdditionalInfo> {
        let tracksOperation = StorageConstantOperation<[Referenda.Track]>(path: Referenda.tracks)

        tracksOperation.configurationBlock = {
            do {
                tracksOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                tracksOperation.result = .failure(error)
            }
        }

        let undecidingTimeoutOperation = PrimitiveConstantOperation<Moment>(path: Referenda.undecidingTimeout)

        undecidingTimeoutOperation.configurationBlock = {
            do {
                undecidingTimeoutOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                undecidingTimeoutOperation.result = .failure(error)
            }
        }

        let lockingPeriodOperation = PrimitiveConstantOperation<Moment>(path: ConvictionVoting.voteLockingPeriodPath)

        lockingPeriodOperation.configurationBlock = {
            do {
                lockingPeriodOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                lockingPeriodOperation.result = .failure(error)
            }
        }

        let fetchOperations = [tracksOperation, undecidingTimeoutOperation, lockingPeriodOperation]
        fetchOperations.forEach { $0.addDependency(codingFactoryOperation) }

        let mappingOperation = ClosureOperation<AdditionalInfo> {
            let tracks = try tracksOperation.extractNoCancellableResultData().reduce(
                into: [Referenda.TrackId: Referenda.TrackInfo]()
            ) { $0[$1.trackId] = $1.info }

            let undecidingTimeout = try undecidingTimeoutOperation.extractNoCancellableResultData()

            let lockingPeriod = try lockingPeriodOperation.extractNoCancellableResultData()

            return AdditionalInfo(
                tracks: tracks,
                undecidingTimeout: undecidingTimeout,
                voteLockingPeriod: lockingPeriod
            )
        }

        fetchOperations.forEach { mappingOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: fetchOperations)
    }

    private func estimateVoteLockingPeriod(
        for referendumInfo: ReferendumInfo,
        accountVote: ReferendumAccountVoteLocal,
        additionalInfo: AdditionalInfo
    ) -> BlockNumber? {
        let conviction = accountVote.convictionValue

        guard let convictionPeriod = conviction.conviction(for: additionalInfo.voteLockingPeriod) else {
            return nil
        }

        switch referendumInfo {
        case let .ongoing(ongoingStatus):
            guard let track = additionalInfo.tracks[ongoingStatus.track] else {
                return nil
            }

            if let decidingSince = ongoingStatus.deciding?.since {
                return decidingSince + track.decisionPeriod + convictionPeriod
            } else {
                return ongoingStatus.submitted + additionalInfo.undecidingTimeout +
                    track.decisionPeriod + convictionPeriod
            }
        case let .approved(completedStatus):
            if accountVote.ayes > 0 {
                return completedStatus.since + convictionPeriod
            } else {
                return nil
            }
        case let .rejected(completedStatus):
            if accountVote.nays > 0 {
                return completedStatus.since + convictionPeriod
            } else {
                return nil
            }
        case .unknown, .killed, .timedOut, .cancelled:
            return nil
        }
    }

    private func calculatePriorLockMax(from trackVotes: ReferendumTracksVotingDistribution) -> BlockNumber? {
        let optCastingMax = trackVotes.votes.priorLocks.values
            .filter { $0.amount > 0 }
            .map(\.unlockAt)
            .max()

        let optDelegatingMax = trackVotes.votes.delegatings.values
            .compactMap { $0.prior.amount > 0 ? $0.prior.unlockAt : nil }
            .max()

        if let castingMax = optCastingMax, let delegatingMax = optDelegatingMax {
            return max(castingMax, delegatingMax)
        } else if let castingMax = optCastingMax {
            return castingMax
        } else {
            return optDelegatingMax
        }
    }

    private func calculateMaxLock(
        for referendums: [ReferendumIdLocal: ReferendumInfo],
        trackVotes: ReferendumTracksVotingDistribution,
        additions: AdditionalInfo
    ) -> BlockNumber? {
        let optVotesMax: Moment? = referendums.compactMap { referendumKeyValue in
            let referendumIndex = referendumKeyValue.key
            let referendum = referendumKeyValue.value

            let accountVoting = trackVotes.votes
            guard let vote = accountVoting.votes[referendumIndex], vote.totalBalance > 0 else {
                return nil
            }

            return estimateVoteLockingPeriod(for: referendum, accountVote: vote, additionalInfo: additions)
        }.max()

        let optPriorMax = calculatePriorLockMax(from: trackVotes)

        if let votesMax = optVotesMax, let priorMax = optPriorMax {
            return max(votesMax, priorMax)
        } else if let votesMax = optVotesMax {
            return votesMax
        } else {
            return optPriorMax
        }
    }

    private func createStateDiffOperation(
        for trackVotes: ReferendumTracksVotingDistribution,
        newVote: ReferendumNewVote?,
        referendumsOperation: BaseOperation<[ReferendumIdLocal: ReferendumInfo]>,
        additionalInfoOperation: BaseOperation<AdditionalInfo>
    ) -> BaseOperation<GovernanceLockStateDiff> {
        ClosureOperation<GovernanceLockStateDiff> {
            let referendums = try referendumsOperation.extractNoCancellableResultData()
            let additions = try additionalInfoOperation.extractNoCancellableResultData()

            let oldAmount = trackVotes.trackLocks.map(\.amount).max() ?? 0

            let oldPeriod: Moment? = self.calculateMaxLock(
                for: referendums,
                trackVotes: trackVotes,
                additions: additions
            )

            let oldState = GovernanceLockState(maxLockedAmount: oldAmount, lockedUntil: oldPeriod)

            let newState: GovernanceLockState?

            if let newVote = newVote, newVote.voteAction.amount > 0 {
                let newAmount = max(oldAmount, newVote.voteAction.amount)

                // as we replacing the vote we can immediately claim previos one so don't take into account
                let filteredReferendums = referendums.filter { $0.key != newVote.index }

                let periodWithoutReferendum = self.calculateMaxLock(
                    for: filteredReferendums,
                    trackVotes: trackVotes,
                    additions: additions
                )

                let newPeriod: Moment?

                if
                    let referendum = referendums[newVote.index],
                    let periodWithNewVote = self.estimateVoteLockingPeriod(
                        for: referendum,
                        accountVote: newVote.toAccountVote(),
                        additionalInfo: additions
                    ) {
                    newPeriod = periodWithoutReferendum.flatMap { max(periodWithNewVote, $0) } ?? periodWithNewVote
                } else {
                    newPeriod = periodWithoutReferendum
                }

                newState = GovernanceLockState(maxLockedAmount: newAmount, lockedUntil: newPeriod)
            } else {
                newState = nil
            }

            return GovernanceLockStateDiff(before: oldState, vote: newVote, after: newState)
        }
    }
}

extension Gov2LockStateFactory: GovernanceLockStateFactoryProtocol {
    func calculateLockStateDiff(
        for trackVotes: ReferendumTracksVotingDistribution,
        newVote: ReferendumNewVote?,
        from connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        blockHash: Data?
    ) -> CompoundOperationWrapper<GovernanceLockStateDiff> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let accountVoting = trackVotes.votes
        var allReferendumIds = Set(accountVoting.votes.keys)

        if let newVoteIndex = newVote?.index {
            allReferendumIds.insert(newVoteIndex)
        }

        let referendumsWrapper = createReferendumsWrapper(
            for: allReferendumIds,
            connection: connection,
            codingFactoryOperation: codingFactoryOperation,
            blockHash: blockHash
        )

        let additionalInfoWrapper = createAdditionalInfoWrapper(dependingOn: codingFactoryOperation)

        referendumsWrapper.addDependency(operations: [codingFactoryOperation])
        additionalInfoWrapper.addDependency(operations: [codingFactoryOperation])

        let calculationOperation = createStateDiffOperation(
            for: trackVotes,
            newVote: newVote,
            referendumsOperation: referendumsWrapper.targetOperation,
            additionalInfoOperation: additionalInfoWrapper.targetOperation
        )

        calculationOperation.addDependency(referendumsWrapper.targetOperation)
        calculationOperation.addDependency(additionalInfoWrapper.targetOperation)

        let dependencies = [codingFactoryOperation] + referendumsWrapper.allOperations +
            additionalInfoWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: calculationOperation, dependencies: dependencies)
    }
}
