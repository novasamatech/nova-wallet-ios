import Foundation
import RobinHood
import SubstrateSdk
import BigInt

/**
 *  Class that calculates:
 *  Locked amount diff - maximum amount of tokens locked before vote/delegation is applied and after;
 *  Locked period diff - period of time needed to unlock all the tokens before vote is applied and after;
 *  Undelegating period diff - period of time needed to unlock delegated tokens;
 *
 *  Locked amount calculation assumes that no unlocks can happen during
 *  voting (event if voting for the same referendum). So the diff may not decrease.
 *
 *  Locked period is calculated first by maximizing estimation for unlock block of votes (only nonzero amount).
 *  And then maximizing result between maximum period for votes and prior locks
 *  (taking into account both casting votes and delegations).
 *
 *  Note that locked period calculation uses an estimation that takes maximum time when voting for particular referendum
 *  may end.
 */

class GovernanceLockStateFactory {
    let requestFactory: StorageRequestFactoryProtocol
    let unlocksCalculator: GovernanceUnlockCalculatorProtocol

    init(requestFactory: StorageRequestFactoryProtocol, unlocksCalculator: GovernanceUnlockCalculatorProtocol) {
        self.requestFactory = requestFactory
        self.unlocksCalculator = unlocksCalculator
    }

    func createReferendumsWrapper(
        for _: Set<ReferendumIdLocal>,
        connection _: JSONRPCEngine,
        codingFactoryOperation _: BaseOperation<RuntimeCoderFactoryProtocol>,
        blockHash _: Data?
    ) -> CompoundOperationWrapper<[ReferendumIdLocal: GovUnlockReferendumProtocol]> {
        fatalError("Child class must implement this method")
    }

    func createAdditionalInfoWrapper(
        dependingOn _: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<GovUnlockCalculationInfo> {
        fatalError("Child class must implement this method")
    }

    func calculatePriorLockMax(from trackVotes: ReferendumTracksVotingDistribution) -> BlockNumber? {
        let optCastingMax = trackVotes.votes.priorLocks.values
            .filter { $0.exists }
            .map(\.unlockAt)
            .max()

        let optDelegatingMax = trackVotes.votes.delegatings.values
            .compactMap { $0.prior.exists ? $0.prior.unlockAt : nil }
            .max()

        if let castingMax = optCastingMax, let delegatingMax = optDelegatingMax {
            return max(castingMax, delegatingMax)
        } else if let castingMax = optCastingMax {
            return castingMax
        } else {
            return optDelegatingMax
        }
    }

    func calculateMaxLock(
        for referendums: [ReferendumIdLocal: GovUnlockReferendumProtocol],
        trackVotes: ReferendumTracksVotingDistribution,
        additions: GovUnlockCalculationInfo
    ) -> BlockNumber? {
        let optVotesMax: Moment? = referendums.compactMap { referendumKeyValue in
            let referendumIndex = referendumKeyValue.key
            let referendum = referendumKeyValue.value

            let accountVoting = trackVotes.votes
            guard let vote = accountVoting.votes[referendumIndex] else {
                return nil
            }

            return try? referendum.estimateVoteLockingPeriod(
                for: vote,
                additionalInfo: additions
            )
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

    func createStateDiffOperation(
        for trackVotes: ReferendumTracksVotingDistribution,
        newVote: ReferendumNewVote?,
        referendumsOperation: BaseOperation<[ReferendumIdLocal: GovUnlockReferendumProtocol]>,
        additionalInfoOperation: BaseOperation<GovUnlockCalculationInfo>
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

            if let newVote = newVote {
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
                    let periodWithNewVote = try? referendum.estimateVoteLockingPeriod(
                        for: newVote.toAccountVote(),
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

    func createDelegateStateDiffOperation(
        for trackVotes: ReferendumTracksVotingDistribution,
        newDelegation: GovernanceNewDelegation,
        additionalInfoOperation: BaseOperation<GovUnlockCalculationInfo>
    ) -> BaseOperation<GovernanceDelegateStateDiff> {
        ClosureOperation<GovernanceDelegateStateDiff> {
            let additions = try additionalInfoOperation.extractNoCancellableResultData()

            let oldAmount = trackVotes.trackLocks.map(\.amount).max() ?? 0

            let oldPeriod = trackVotes.votes.delegatings.values.compactMap { delegation in
                delegation.conviction.conviction(for: additions.voteLockingPeriod)
            }.max()

            let oldState = GovernanceDelegateState(
                maxLockedAmount: oldAmount,
                undelegatingPeriod: oldPeriod
            )

            let newState: GovernanceDelegateState?

            let newAmount = max(oldAmount, newDelegation.balance)

            let newPeriod = newDelegation.conviction.conviction(for: additions.voteLockingPeriod)

            newState = GovernanceDelegateState(maxLockedAmount: newAmount, undelegatingPeriod: newPeriod)

            return GovernanceDelegateStateDiff(
                before: oldState,
                delegation: newDelegation,
                after: newState
            )
        }
    }
}

extension GovernanceLockStateFactory: GovernanceLockStateFactoryProtocol {
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

    func calculateDelegateStateDiff(
        for trackVotes: ReferendumTracksVotingDistribution,
        newDelegation: GovernanceNewDelegation,
        runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<GovernanceDelegateStateDiff> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let additionalInfoWrapper = createAdditionalInfoWrapper(dependingOn: codingFactoryOperation)

        additionalInfoWrapper.addDependency(operations: [codingFactoryOperation])

        let calculationOperation = createDelegateStateDiffOperation(
            for: trackVotes,
            newDelegation: newDelegation,
            additionalInfoOperation: additionalInfoWrapper.targetOperation
        )

        calculationOperation.addDependency(additionalInfoWrapper.targetOperation)

        let dependencies = [codingFactoryOperation] + additionalInfoWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: calculationOperation, dependencies: dependencies)
    }

    func buildUnlockScheduleWrapper(
        for tracksVoting: ReferendumTracksVotingDistribution,
        from connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        blockHash: Data?
    ) -> CompoundOperationWrapper<GovernanceUnlockSchedule> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let accountVoting = tracksVoting.votes
        let allReferendumIds = Set(accountVoting.votes.keys)

        let referendumsWrapper = createReferendumsWrapper(
            for: allReferendumIds,
            connection: connection,
            codingFactoryOperation: codingFactoryOperation,
            blockHash: blockHash
        )

        let additionalInfoWrapper = createAdditionalInfoWrapper(dependingOn: codingFactoryOperation)

        referendumsWrapper.addDependency(operations: [codingFactoryOperation])
        additionalInfoWrapper.addDependency(operations: [codingFactoryOperation])

        let scheduleOperation = ClosureOperation<GovernanceUnlockSchedule> {
            let referendums = try referendumsWrapper.targetOperation.extractNoCancellableResultData()
            let additions = try additionalInfoWrapper.targetOperation.extractNoCancellableResultData()

            return self.unlocksCalculator.createUnlocksSchedule(
                for: tracksVoting,
                referendums: referendums,
                additionalInfo: additions
            )
        }

        scheduleOperation.addDependency(referendumsWrapper.targetOperation)
        scheduleOperation.addDependency(additionalInfoWrapper.targetOperation)

        let dependencies = [codingFactoryOperation] + referendumsWrapper.allOperations +
            additionalInfoWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: scheduleOperation, dependencies: dependencies)
    }
}
