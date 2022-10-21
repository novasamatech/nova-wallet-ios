import Foundation
import RobinHood
import SubstrateSdk
import BigInt

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

    private func calculateLocking(
        for referendumInfo: ReferendumInfo,
        accountVote: ReferendumAccountVoteLocal,
        additionalInfo: AdditionalInfo
    ) -> BlockNumber? {
        let conviction = accountVote.convictionValue ?? .none

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

    private func createStateDiffOperation(
        for votes: [ReferendumIdLocal: ReferendumAccountVoteLocal],
        newVote: ReferendumNewVote?,
        referendumsOperation: BaseOperation<[ReferendumIdLocal: ReferendumInfo]>,
        additionalInfoOperation: BaseOperation<AdditionalInfo>
    ) -> BaseOperation<GovernanceLockStateDiff> {
        ClosureOperation<GovernanceLockStateDiff> {
            let referendums = try referendumsOperation.extractNoCancellableResultData()
            let additions = try additionalInfoOperation.extractNoCancellableResultData()

            let oldAmount = votes.values.map(\.totalBalance).max() ?? 0

            let oldPeriod: Moment? = referendums.compactMap { referendumKeyValue in
                let referendumIndex = referendumKeyValue.key
                let referendum = referendumKeyValue.value

                guard let vote = votes[referendumIndex], vote.totalBalance > 0 else {
                    return nil
                }

                return self.calculateLocking(for: referendum, accountVote: vote, additionalInfo: additions)
            }.max()

            let oldState = GovernanceLockState(maxLockedAmount: oldAmount, lockedUntil: oldPeriod)

            let newState: GovernanceLockState?

            if let newVote = newVote {
                let filteredVotes = votes.filter { $0.key != newVote.index }
                let newAmount = (filteredVotes.values.map(\.totalBalance) + [newVote.voteAction.amount]).max() ?? 0

                let newPeriod: Moment? = referendums.compactMap { referendumKeyValue in
                    let referendumIndex = referendumKeyValue.key
                    let referendum = referendumKeyValue.value

                    let accountVote: ReferendumAccountVoteLocal

                    if referendumIndex == newVote.index {
                        guard newVote.voteAction.amount > 0 else {
                            return nil
                        }

                        accountVote = newVote.toAccountVote()
                    } else {
                        guard let vote = filteredVotes[referendumIndex], vote.totalBalance > 0 else {
                            return nil
                        }

                        accountVote = vote
                    }

                    return self.calculateLocking(for: referendum, accountVote: accountVote, additionalInfo: additions)
                }.max()

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
        for votes: [ReferendumIdLocal: ReferendumAccountVoteLocal],
        newVote: ReferendumNewVote?,
        from connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        blockHash: Data?
    ) -> CompoundOperationWrapper<GovernanceLockStateDiff> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        var allReferendumIds = Set(votes.keys)

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
            for: votes,
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
