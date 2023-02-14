import Foundation
import SubstrateSdk
import RobinHood
import BigInt

extension Gov2OperationFactory: ReferendumsOperationFactoryProtocol {
    func fetchAllReferendumsWrapper(
        from connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<[ReferendumLocal]> {
        let request = UnkeyedRemoteStorageRequest(storagePath: Referenda.referendumInfo)

        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let referendumWrapper: CompoundOperationWrapper<[ReferendumIndexKey: ReferendumInfo]> =
            requestFactory.queryByPrefix(
                engine: connection,
                request: request,
                storagePath: request.storagePath,
                factory: { try codingFactoryOperation.extractNoCancellableResultData() }
            )

        referendumWrapper.addDependency(operations: [codingFactoryOperation])

        let additionalInfoWrapper = createAdditionalInfoWrapper(
            from: connection,
            runtimeProvider: runtimeProvider,
            blockHash: nil
        )

        let enactmentsWrapper = createEnacmentTimeFetchWrapper(
            dependingOn: referendumWrapper.targetOperation,
            connection: connection,
            runtimeProvider: runtimeProvider,
            blockHash: nil
        )

        enactmentsWrapper.addDependency(wrapper: referendumWrapper)

        let inQueueStateWrapper = createTrackQueueOperation(
            dependingOn: referendumWrapper.targetOperation,
            connection: connection,
            runtimeProvider: runtimeProvider,
            requestFactory: requestFactory
        )

        inQueueStateWrapper.addDependency(operations: [referendumWrapper.targetOperation])

        let mapOperation = createReferendumMapOperation(
            dependingOn: referendumWrapper.targetOperation,
            additionalInfoOperation: additionalInfoWrapper.targetOperation,
            enactmentsOperation: enactmentsWrapper.targetOperation,
            inQueueOperation: inQueueStateWrapper.targetOperation
        )

        mapOperation.addDependency(referendumWrapper.targetOperation)
        mapOperation.addDependency(additionalInfoWrapper.targetOperation)
        mapOperation.addDependency(enactmentsWrapper.targetOperation)
        mapOperation.addDependency(inQueueStateWrapper.targetOperation)

        let dependencies = [codingFactoryOperation] + referendumWrapper.allOperations +
            additionalInfoWrapper.allOperations + inQueueStateWrapper.allOperations + enactmentsWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    func fetchAllTracks(
        runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<[GovernanceTrackInfoLocal]> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let tracksOperation = StorageConstantOperation<[Referenda.Track]>(path: Referenda.tracks)

        tracksOperation.configurationBlock = {
            do {
                tracksOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                tracksOperation.result = .failure(error)
            }
        }

        let mapOperation = ClosureOperation<[GovernanceTrackInfoLocal]> {
            try tracksOperation.extractNoCancellableResultData().map { track in
                GovernanceTrackInfoLocal(
                    trackId: TrackIdLocal(track.trackId),
                    name: track.info.name
                )
            }
        }

        tracksOperation.addDependency(codingFactoryOperation)
        mapOperation.addDependency(tracksOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [codingFactoryOperation, tracksOperation]
        )
    }

    func fetchReferendumWrapper(
        for remoteReferendum: ReferendumInfo,
        index: ReferendumIdLocal,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        blockHash: Data?
    ) -> CompoundOperationWrapper<ReferendumLocal> {
        let additionalInfoWrapper = createAdditionalInfoWrapper(
            from: connection,
            runtimeProvider: runtimeProvider,
            blockHash: blockHash
        )

        let referendumOperation = ClosureOperation<[ReferendumIndexKey: ReferendumInfo]> {
            let referendumIndexKey = ReferendumIndexKey(referendumIndex: Referenda.ReferendumIndex(index))
            return [referendumIndexKey: remoteReferendum]
        }

        let enactmentsWrapper = createEnacmentTimeFetchWrapper(
            dependingOn: referendumOperation,
            connection: connection,
            runtimeProvider: runtimeProvider,
            blockHash: blockHash
        )

        enactmentsWrapper.addDependency(operations: [referendumOperation])

        let inQueueStateWrapper = createTrackQueueOperation(
            dependingOn: referendumOperation,
            connection: connection,
            runtimeProvider: runtimeProvider,
            requestFactory: requestFactory
        )

        inQueueStateWrapper.addDependency(operations: [referendumOperation])

        let mergeOperation = createReferendumMapOperation(
            dependingOn: referendumOperation,
            additionalInfoOperation: additionalInfoWrapper.targetOperation,
            enactmentsOperation: enactmentsWrapper.targetOperation,
            inQueueOperation: inQueueStateWrapper.targetOperation
        )

        mergeOperation.addDependency(referendumOperation)
        mergeOperation.addDependency(additionalInfoWrapper.targetOperation)
        mergeOperation.addDependency(enactmentsWrapper.targetOperation)
        mergeOperation.addDependency(inQueueStateWrapper.targetOperation)

        let mapOperation = ClosureOperation<ReferendumLocal> {
            guard let referendum = try mergeOperation.extractNoCancellableResultData().first else {
                throw BaseOperationError.unexpectedDependentResult
            }

            return referendum
        }

        mapOperation.addDependency(mergeOperation)

        let dependencies = [referendumOperation] + additionalInfoWrapper.allOperations +
            enactmentsWrapper.allOperations + inQueueStateWrapper.allOperations + [mergeOperation]

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    func fetchAccountVotesWrapper(
        for accountId: AccountId,
        from connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        blockHash: Data?
    ) -> CompoundOperationWrapper<ReferendumAccountVotingDistribution> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let request = MapRemoteStorageRequest(storagePath: ConvictionVoting.votingFor) {
            BytesCodable(wrappedValue: accountId)
        }

        let votesWrapper: CompoundOperationWrapper<[ConvictionVoting.VotingForKey: ConvictionVoting.Voting]> =
            requestFactory.queryByPrefix(
                engine: connection,
                request: request,
                storagePath: ConvictionVoting.votingFor,
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                at: blockHash
            )

        votesWrapper.addDependency(operations: [codingFactoryOperation])

        let maxVotesOperation = createMaxVotesOperation(dependingOn: codingFactoryOperation)
        maxVotesOperation.addDependency(codingFactoryOperation)

        let mappingOperation = ClosureOperation<ReferendumAccountVotingDistribution> {
            let voting = try votesWrapper.targetOperation.extractNoCancellableResultData()
            let maxVotes = try maxVotesOperation.extractNoCancellableResultData()

            let initVotingLocal = ReferendumAccountVotingDistribution(maxVotesPerTrack: maxVotes)

            return voting.reduce(initVotingLocal) { resultVoting, votingKeyValue in
                let voting = votingKeyValue.value
                let track = TrackIdLocal(votingKeyValue.key.trackId)
                switch voting {
                case let .casting(castingVoting):
                    return castingVoting.votes.reduce(resultVoting) { result, vote in
                        let newResult = result.addingReferendum(ReferendumIdLocal(vote.pollIndex), track: track)

                        guard let localVote = ReferendumAccountVoteLocal(accountVote: vote.accountVote) else {
                            return newResult
                        }

                        return newResult.addingVote(localVote, referendumId: ReferendumIdLocal(vote.pollIndex))
                    }.addingPriorLock(castingVoting.prior, track: track)
                case let .delegating(delegatingVoting):
                    let delegatingLocal = ReferendumDelegatingLocal(remote: delegatingVoting)
                    return resultVoting.addingDelegating(delegatingLocal, trackId: track)
                case .unknown:
                    return resultVoting
                }
            }
        }

        mappingOperation.addDependency(votesWrapper.targetOperation)
        mappingOperation.addDependency(maxVotesOperation)

        let dependencies = [codingFactoryOperation, maxVotesOperation] + votesWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: dependencies)
    }

    func fetchVotersWrapper(
        for referendumIndex: ReferendumIdLocal,
        from connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<[ReferendumVoterLocal]> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let request = UnkeyedRemoteStorageRequest(storagePath: ConvictionVoting.votingFor)

        let votesWrapper: CompoundOperationWrapper<[ConvictionVoting.VotingForKey: ConvictionVoting.Voting]> =
            requestFactory.queryByPrefix(
                engine: connection,
                request: request,
                storagePath: ConvictionVoting.votingFor,
                factory: { try codingFactoryOperation.extractNoCancellableResultData() }
            )

        votesWrapper.addDependency(operations: [codingFactoryOperation])

        let mappingOperation = ClosureOperation<[ReferendumVoterLocal]> {
            let votesResult = try votesWrapper.targetOperation.extractNoCancellableResultData()

            return votesResult.compactMap { keyValue in
                let accountId = keyValue.key.accountId
                let voting = keyValue.value

                switch voting {
                case let .casting(castingVoting):
                    guard
                        let vote = castingVoting.votes.first(where: { $0.pollIndex == referendumIndex }),
                        let accountVote = ReferendumAccountVoteLocal(accountVote: vote.accountVote) else {
                        return nil
                    }

                    return ReferendumVoterLocal(accountId: accountId, vote: accountVote)
                case .delegating, .unknown:
                    return nil
                }
            }
        }

        mappingOperation.addDependency(votesWrapper.targetOperation)

        let dependencies = [codingFactoryOperation] + votesWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: dependencies)
    }

    func fetchReferendumsWrapper(
        for referendumIds: Set<ReferendumIdLocal>,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<[ReferendumLocal]> {
        let remoteIndexes = Array(referendumIds.map { StringScaleMapper(value: $0) })
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let wrapper: CompoundOperationWrapper<[StorageResponse<ReferendumInfo>]> = requestFactory.queryItems(
            engine: connection,
            keyParams: { remoteIndexes },
            factory: { try codingFactoryOperation.extractNoCancellableResultData() },
            storagePath: Referenda.referendumInfo,
            at: nil
        )
        wrapper.addDependency(operations: [codingFactoryOperation])

        let referendumOperation = ClosureOperation<[ReferendumIndexKey: ReferendumInfo]> {
            let responses = try wrapper.targetOperation.extractNoCancellableResultData()

            let initAccum = [ReferendumIndexKey: ReferendumInfo]()
            return zip(remoteIndexes, responses).reduce(into: initAccum) { accum, pair in
                accum[ReferendumIndexKey(referendumIndex: Referenda.ReferendumIndex(pair.0.value))] = pair.1.value
            }
        }

        referendumOperation.addDependency(wrapper.targetOperation)

        let additionalInfoWrapper = createAdditionalInfoWrapper(
            from: connection,
            runtimeProvider: runtimeProvider,
            blockHash: nil
        )

        let enactmentsWrapper = createEnacmentTimeFetchWrapper(
            dependingOn: referendumOperation,
            connection: connection,
            runtimeProvider: runtimeProvider,
            blockHash: nil
        )

        enactmentsWrapper.addDependency(operations: [referendumOperation])

        let inQueueStateWrapper = createTrackQueueOperation(
            dependingOn: referendumOperation,
            connection: connection,
            runtimeProvider: runtimeProvider,
            requestFactory: requestFactory
        )

        inQueueStateWrapper.addDependency(operations: [referendumOperation])

        let mapOperation = createReferendumMapOperation(
            dependingOn: referendumOperation,
            additionalInfoOperation: additionalInfoWrapper.targetOperation,
            enactmentsOperation: enactmentsWrapper.targetOperation,
            inQueueOperation: inQueueStateWrapper.targetOperation
        )

        mapOperation.addDependency(referendumOperation)
        mapOperation.addDependency(additionalInfoWrapper.targetOperation)
        mapOperation.addDependency(enactmentsWrapper.targetOperation)
        mapOperation.addDependency(inQueueStateWrapper.targetOperation)

        let dependencies = [codingFactoryOperation] + wrapper.allOperations + [referendumOperation] +
            additionalInfoWrapper.allOperations + inQueueStateWrapper.allOperations + enactmentsWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }
}
