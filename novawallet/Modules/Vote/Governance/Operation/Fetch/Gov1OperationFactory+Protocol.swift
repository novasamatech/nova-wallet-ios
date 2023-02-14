import Foundation
import RobinHood
import BigInt
import SubstrateSdk

extension Gov1OperationFactory: ReferendumsOperationFactoryProtocol {
    func fetchAllReferendumsWrapper(
        from connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<[ReferendumLocal]> {
        let request = UnkeyedRemoteStorageRequest(storagePath: Democracy.referendumInfo)

        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let referendumWrapper: CompoundOperationWrapper<[ReferendumIndexKey: Democracy.ReferendumInfo]> =
            requestFactory.queryByPrefix(
                engine: connection,
                request: request,
                storagePath: request.storagePath,
                factory: { try codingFactoryOperation.extractNoCancellableResultData() }
            )

        referendumWrapper.addDependency(operations: [codingFactoryOperation])

        let enactmentsWrapper = createEnacmentTimeFetchWrapper(
            dependingOn: referendumWrapper.targetOperation,
            connection: connection,
            runtimeProvider: runtimeProvider,
            blockHash: nil
        )

        enactmentsWrapper.addDependency(wrapper: referendumWrapper)

        let additionalWrapper = createAdditionalInfoWrapper(
            dependingOn: codingFactoryOperation,
            connection: connection,
            blockHash: nil
        )

        additionalWrapper.addDependency(operations: [codingFactoryOperation])

        let mapOperation = createReferendumMapOperation(
            dependingOn: referendumWrapper.targetOperation,
            additionalInfoOperation: additionalWrapper.targetOperation,
            enactmentsOperation: enactmentsWrapper.targetOperation
        )

        mapOperation.addDependency(additionalWrapper.targetOperation)
        mapOperation.addDependency(referendumWrapper.targetOperation)
        mapOperation.addDependency(enactmentsWrapper.targetOperation)

        let dependencies = [codingFactoryOperation] + referendumWrapper.allOperations +
            enactmentsWrapper.allOperations + additionalWrapper.allOperations

        return .init(targetOperation: mapOperation, dependencies: dependencies)
    }

    func fetchReferendumWrapper(
        for remoteReferendum: Democracy.ReferendumInfo,
        index: ReferendumIdLocal,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        blockHash: Data?
    ) -> CompoundOperationWrapper<ReferendumLocal> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let additionalInfoWrapper = createAdditionalInfoWrapper(
            dependingOn: codingFactoryOperation,
            connection: connection,
            blockHash: blockHash
        )

        additionalInfoWrapper.addDependency(operations: [codingFactoryOperation])

        let referendumOperation = ClosureOperation<[ReferendumIndexKey: Democracy.ReferendumInfo]> {
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

        let dependencies = [codingFactoryOperation, referendumOperation] +
            additionalInfoWrapper.allOperations + enactmentsWrapper.allOperations + [mergeOperation]

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    func fetchTracksVotingWrapper(
        for voting: Democracy.Voting?,
        accountId: AccountId,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        blockHash: Data?
    ) -> CompoundOperationWrapper<ReferendumTracksVotingDistribution> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let lockKeys: () throws -> [BytesCodable] = {
            [BytesCodable(wrappedValue: accountId)]
        }

        let locksWrapper: CompoundOperationWrapper<[StorageResponse<BalanceLocks>]> = requestFactory.queryItems(
            engine: connection,
            keyParams: lockKeys,
            factory: { try codingFactoryOperation.extractNoCancellableResultData() },
            storagePath: .balanceLocks,
            at: blockHash
        )

        locksWrapper.addDependency(operations: [codingFactoryOperation])

        let maxVotesOperation = createMaxVotesOperation(dependingOn: codingFactoryOperation)
        maxVotesOperation.addDependency(codingFactoryOperation)

        let mappingOperation = ClosureOperation<ReferendumTracksVotingDistribution> {
            let maxVotes = try maxVotesOperation.extractNoCancellableResultData()
            let locks = try locksWrapper.targetOperation.extractNoCancellableResultData().first?.value

            let lockedAmount = locks?
                .first { String(data: $0.identifier, encoding: .utf8) == Democracy.lockId }?
                .amount ?? 0

            return Gov1LocalMappingFactory().mapToTracksVoting(voting, lockedBalance: lockedAmount, maxVotes: maxVotes)
        }

        mappingOperation.addDependency(maxVotesOperation)
        mappingOperation.addDependency(locksWrapper.targetOperation)

        let dependencies = [codingFactoryOperation, maxVotesOperation] + locksWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: dependencies)
    }

    func fetchAccountVotesWrapper(
        for accountId: AccountId,
        from connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        blockHash: Data?
    ) -> CompoundOperationWrapper<ReferendumAccountVotingDistribution> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let keyParams: () throws -> [BytesCodable] = {
            [BytesCodable(wrappedValue: accountId)]
        }

        let votesWrapper: CompoundOperationWrapper<[StorageResponse<Democracy.Voting>]> =
            requestFactory.queryItems(
                engine: connection,
                keyParams: keyParams,
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: Democracy.votingOf,
                at: blockHash
            )

        votesWrapper.addDependency(operations: [codingFactoryOperation])

        let maxVotesOperation = createMaxVotesOperation(dependingOn: codingFactoryOperation)
        maxVotesOperation.addDependency(codingFactoryOperation)

        let mappingOperation = ClosureOperation<ReferendumAccountVotingDistribution> {
            let optVoting = try votesWrapper.targetOperation.extractNoCancellableResultData().first?.value
            let maxVotes = try maxVotesOperation.extractNoCancellableResultData()

            return Gov1LocalMappingFactory().mapToAccountVoting(optVoting, maxVotes: maxVotes)
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

        let request = UnkeyedRemoteStorageRequest(storagePath: Democracy.votingOf)

        let votesWrapper: CompoundOperationWrapper<[Democracy.VotingOfKey: Democracy.Voting]> =
            requestFactory.queryByPrefix(
                engine: connection,
                request: request,
                storagePath: Democracy.votingOf,
                factory: { try codingFactoryOperation.extractNoCancellableResultData() }
            )

        votesWrapper.addDependency(operations: [codingFactoryOperation])

        let mappingOperation = ClosureOperation<[ReferendumVoterLocal]> {
            let votesResult = try votesWrapper.targetOperation.extractNoCancellableResultData()

            return votesResult.compactMap { keyValue in
                let accountId = keyValue.key.accountId
                let voting = keyValue.value

                switch voting {
                case let .direct(directVoting):
                    guard
                        let vote = directVoting.votes.first(where: { $0.pollIndex == referendumIndex }),
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

        let wrapper: CompoundOperationWrapper<[StorageResponse<Democracy.ReferendumInfo>]> = requestFactory.queryItems(
            engine: connection,
            keyParams: { remoteIndexes },
            factory: { try codingFactoryOperation.extractNoCancellableResultData() },
            storagePath: Democracy.referendumInfo,
            at: nil
        )
        wrapper.addDependency(operations: [codingFactoryOperation])

        let referendumOperation = ClosureOperation<[ReferendumIndexKey: Democracy.ReferendumInfo]> {
            let responses = try wrapper.targetOperation.extractNoCancellableResultData()

            let initAccum = [ReferendumIndexKey: Democracy.ReferendumInfo]()
            return zip(remoteIndexes, responses).reduce(into: initAccum) { accum, pair in
                accum[ReferendumIndexKey(referendumIndex: Referenda.ReferendumIndex(pair.0.value))] = pair.1.value
            }
        }

        referendumOperation.addDependency(wrapper.targetOperation)

        let enactmentsWrapper = createEnacmentTimeFetchWrapper(
            dependingOn: referendumOperation,
            connection: connection,
            runtimeProvider: runtimeProvider,
            blockHash: nil
        )

        enactmentsWrapper.addDependency(operations: [referendumOperation])

        let additionalWrapper = createAdditionalInfoWrapper(
            dependingOn: codingFactoryOperation,
            connection: connection,
            blockHash: nil
        )

        additionalWrapper.addDependency(operations: [codingFactoryOperation])

        let mapOperation = createReferendumMapOperation(
            dependingOn: referendumOperation,
            additionalInfoOperation: additionalWrapper.targetOperation,
            enactmentsOperation: enactmentsWrapper.targetOperation
        )

        mapOperation.addDependency(additionalWrapper.targetOperation)
        mapOperation.addDependency(referendumOperation)
        mapOperation.addDependency(enactmentsWrapper.targetOperation)

        let dependencies = [codingFactoryOperation] + wrapper.allOperations + [referendumOperation] +
            enactmentsWrapper.allOperations + additionalWrapper.allOperations

        return .init(targetOperation: mapOperation, dependencies: dependencies)
    }
}
