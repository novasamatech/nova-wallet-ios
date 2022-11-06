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

        let additionalWrapper = createAdditionalInfoWrapper(
            dependingOn: codingFactoryOperation,
            connection: connection,
            blockHash: nil
        )

        additionalWrapper.addDependency(operations: [codingFactoryOperation])

        let mapOperation = createReferendumMapOperation(
            dependingOn: referendumWrapper.targetOperation,
            additionalInfoOperation: additionalWrapper.targetOperation
        )

        mapOperation.addDependency(additionalWrapper.targetOperation)
        mapOperation.addDependency(referendumWrapper.targetOperation)

        return .init(
            targetOperation: mapOperation,
            dependencies: [codingFactoryOperation] + referendumWrapper.allOperations + additionalWrapper.allOperations
        )
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

        let referendumOperation = ClosureOperation<[ReferendumIndexKey: Democracy.ReferendumInfo]> {
            let referendumIndexKey = ReferendumIndexKey(referendumIndex: Referenda.ReferendumIndex(index))
            return [referendumIndexKey: remoteReferendum]
        }

        let mergeOperation = createReferendumMapOperation(
            dependingOn: referendumOperation,
            additionalInfoOperation: additionalInfoWrapper.targetOperation
        )

        mergeOperation.addDependency(referendumOperation)
        mergeOperation.addDependency(additionalInfoWrapper.targetOperation)

        let mapOperation = ClosureOperation<ReferendumLocal> {
            guard let referendum = try mergeOperation.extractNoCancellableResultData().first else {
                throw BaseOperationError.unexpectedDependentResult
            }

            return referendum
        }

        mapOperation.addDependency(mergeOperation)

        let dependencies = [codingFactoryOperation, referendumOperation] +
            additionalInfoWrapper.allOperations + [mergeOperation]

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    func fetchTracksVotingWrapper(
        for voting: Democracy.Voting?,
        runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<ReferendumTracksVotingDistribution> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let maxVotesOperation = createMaxVotesOperation(dependingOn: codingFactoryOperation)
        maxVotesOperation.addDependency(codingFactoryOperation)

        let mappingOperation = ClosureOperation<ReferendumTracksVotingDistribution> {
            let maxVotes = try maxVotesOperation.extractNoCancellableResultData()

            return Gov1LocalMappingFactory().mapVoting(voting, maxVotes: maxVotes)
        }

        mappingOperation.addDependency(maxVotesOperation)

        let dependencies = [codingFactoryOperation, maxVotesOperation]

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

            return Gov1LocalMappingFactory().mapVoting(optVoting, maxVotes: maxVotes).votes
        }

        mappingOperation.addDependency(votesWrapper.targetOperation)
        mappingOperation.addDependency(maxVotesOperation)

        let dependencies = [codingFactoryOperation, maxVotesOperation] + votesWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: dependencies)
    }

    func fetchVotersWrapper(for referendumIndex: ReferendumIdLocal, from connection: JSONRPCEngine, runtimeProvider: RuntimeProviderProtocol) -> CompoundOperationWrapper<[ReferendumVoterLocal]> {
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
}
