import Foundation
import SubstrateSdk
import RobinHood
import BigInt

final class Gov2OperationFactory {
    struct AdditionalInfo {
        let tracks: [Referenda.TrackId: Referenda.TrackInfo]
        let totalIssuance: BigUInt
        let undecidingTimeout: Moment
    }

    struct SchedulerTaskName: Encodable {
        let index: Referenda.ReferendumIndex

        func encode(to encoder: Encoder) throws {
            let scaleEncoder = ScaleEncoder()
            "assembly".data(using: .utf8).map { scaleEncoder.appendRaw(data: $0) }
            try "enactment".encode(scaleEncoder: scaleEncoder)
            try index.encode(scaleEncoder: scaleEncoder)

            let data = try scaleEncoder.encode().blake2b32()

            var container = encoder.singleValueContainer()
            try container.encode(BytesCodable(wrappedValue: data))
        }
    }

    let requestFactory: StorageRequestFactoryProtocol

    init(requestFactory: StorageRequestFactoryProtocol) {
        self.requestFactory = requestFactory
    }

    private func createEnacmentTimeFetchWrapper(
        dependingOn referendumOperation: BaseOperation<[ReferendumIndexKey: ReferendumInfo]>,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        blockHash: Data?
    ) -> CompoundOperationWrapper<[ReferendumIdLocal: BlockNumber]> {
        let keysClosure: () throws -> [SchedulerTaskName] = {
            let referendums = try referendumOperation.extractNoCancellableResultData()

            return referendums.compactMap { keyValue in
                switch keyValue.value {
                case .approved:
                    return SchedulerTaskName(index: keyValue.key.referendumIndex)
                default:
                    return nil
                }
            }
        }

        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let enactmentWrapper: CompoundOperationWrapper<[StorageResponse<OnChainScheduler.TaskAddress>]> =
            requestFactory.queryItems(
                engine: connection,
                keyParams: keysClosure,
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: OnChainScheduler.lookupTaskPath,
                at: blockHash
            )

        enactmentWrapper.addDependency(operations: [codingFactoryOperation])

        let mapOperation = ClosureOperation<[ReferendumIdLocal: BlockNumber]> {
            let keys = try keysClosure()
            let results = try enactmentWrapper.targetOperation.extractNoCancellableResultData()

            return zip(keys, results).reduce(into: [ReferendumIdLocal: BlockNumber]()) { accum, keyResult in
                guard let when = keyResult.1.value?.when else {
                    return
                }

                accum[ReferendumIdLocal(keyResult.0.index)] = when
            }
        }

        mapOperation.addDependency(enactmentWrapper.targetOperation)

        let dependencies = [codingFactoryOperation] + enactmentWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    private func createReferendumMapOperation(
        dependingOn referendumOperation: BaseOperation<[ReferendumIndexKey: ReferendumInfo]>,
        additionalInfoOperation: BaseOperation<AdditionalInfo>,
        enactmentsOperation: BaseOperation<[ReferendumIdLocal: BlockNumber]>
    ) -> BaseOperation<[ReferendumLocal]> {
        ClosureOperation<[ReferendumLocal]> {
            let remoteReferendums = try referendumOperation.extractNoCancellableResultData()
            let additionalInfo = try additionalInfoOperation.extractNoCancellableResultData()
            let enactments = try enactmentsOperation.extractNoCancellableResultData()

            let mappingFactory = Gov2LocalMappingFactory()

            return remoteReferendums.compactMap { keyedReferendum in
                let referendumIndex = ReferendumIdLocal(keyedReferendum.key.referendumIndex)
                let remoteReferendum = keyedReferendum.value

                return mappingFactory.mapRemote(
                    referendum: remoteReferendum,
                    index: Referenda.ReferendumIndex(referendumIndex),
                    additionalInfo: additionalInfo,
                    enactmentBlock: enactments[referendumIndex]
                )
            }
        }
    }

    private func createAdditionalInfoWrapper(
        from connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        blockHash: Data?
    ) -> CompoundOperationWrapper<AdditionalInfo> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let tracksOperation = StorageConstantOperation<[Referenda.Track]>(path: Referenda.tracks)

        tracksOperation.configurationBlock = {
            do {
                tracksOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                tracksOperation.result = .failure(error)
            }
        }

        let undecidingTimeoutOperation = PrimitiveConstantOperation<UInt32>(path: Referenda.undecidingTimeout)

        undecidingTimeoutOperation.configurationBlock = {
            do {
                undecidingTimeoutOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                undecidingTimeoutOperation.result = .failure(error)
            }
        }

        let totalIssuanceWrapper: CompoundOperationWrapper<StorageResponse<StringScaleMapper<BigUInt>>> =
            requestFactory.queryItem(
                engine: connection,
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: .totalIssuance,
                at: blockHash
            )

        let fetchOperations = [tracksOperation, undecidingTimeoutOperation] + totalIssuanceWrapper.allOperations
        fetchOperations.forEach { $0.addDependency(codingFactoryOperation) }

        let mappingOperation = ClosureOperation<AdditionalInfo> {
            let tracks = try tracksOperation.extractNoCancellableResultData().reduce(
                into: [Referenda.TrackId: Referenda.TrackInfo]()
            ) { $0[$1.trackId] = $1.info }

            let undecidingTimeout = try undecidingTimeoutOperation.extractNoCancellableResultData()

            let totalIssuance = try totalIssuanceWrapper.targetOperation.extractNoCancellableResultData().value

            return AdditionalInfo(
                tracks: tracks,
                totalIssuance: totalIssuance?.value ?? 0,
                undecidingTimeout: undecidingTimeout
            )
        }

        let dependencies = [codingFactoryOperation] + fetchOperations

        fetchOperations.forEach { mappingOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: dependencies)
    }
}

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

        let mapOperation = createReferendumMapOperation(
            dependingOn: referendumWrapper.targetOperation,
            additionalInfoOperation: additionalInfoWrapper.targetOperation,
            enactmentsOperation: enactmentsWrapper.targetOperation
        )

        mapOperation.addDependency(referendumWrapper.targetOperation)
        mapOperation.addDependency(additionalInfoWrapper.targetOperation)
        mapOperation.addDependency(enactmentsWrapper.targetOperation)

        let dependencies = [codingFactoryOperation] + referendumWrapper.allOperations +
            additionalInfoWrapper.allOperations + enactmentsWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
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

        let mergeOperation = createReferendumMapOperation(
            dependingOn: referendumOperation,
            additionalInfoOperation: additionalInfoWrapper.targetOperation,
            enactmentsOperation: enactmentsWrapper.targetOperation
        )

        mergeOperation.addDependency(referendumOperation)
        mergeOperation.addDependency(additionalInfoWrapper.targetOperation)
        mergeOperation.addDependency(enactmentsWrapper.targetOperation)

        let mapOperation = ClosureOperation<ReferendumLocal> {
            guard let referendum = try mergeOperation.extractNoCancellableResultData().first else {
                throw BaseOperationError.unexpectedDependentResult
            }

            return referendum
        }

        mapOperation.addDependency(mergeOperation)

        let dependencies = [referendumOperation] + additionalInfoWrapper.allOperations +
            enactmentsWrapper.allOperations + [mergeOperation]

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

        let mappingOperation = ClosureOperation<ReferendumAccountVotingDistribution> {
            let voting = try votesWrapper.targetOperation.extractNoCancellableResultData()

            let initVotingLocal = ReferendumAccountVotingDistribution(votes: [:], delegatings: [:])
            return voting.reduce(initVotingLocal) { resultVoting, votingKeyValue in
                let voting = votingKeyValue.value
                let track = votingKeyValue.key.trackId
                switch voting {
                case let .casting(castingVoting):
                    return castingVoting.votes.reduce(resultVoting) { result, vote in
                        guard let localVote = ReferendumAccountVoteLocal(accountVote: vote.accountVote) else {
                            return result
                        }

                        return result.addingVote(localVote, referendumId: ReferendumIdLocal(vote.pollIndex))
                    }
                case let .delegating(delegatingVoting):
                    let delegatingLocal = ReferendumDelegatingLocal(remote: delegatingVoting)
                    return resultVoting.addingDelegating(delegatingLocal, trackId: TrackIdLocal(track))
                case .unknown:
                    return resultVoting
                }
            }
        }

        mappingOperation.addDependency(votesWrapper.targetOperation)

        let dependencies = [codingFactoryOperation] + votesWrapper.allOperations

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
}
