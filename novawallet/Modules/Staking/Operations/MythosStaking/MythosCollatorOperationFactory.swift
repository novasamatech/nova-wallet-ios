import Foundation
import SubstrateSdk
import Operation_iOS

protocol MythosCollatorOperationFactoryProtocol {
    func createFetchCollatorsInfo(
        for chainId: ChainModel.Id,
        collatorIdsClosure: @escaping () throws -> [AccountId]
    ) -> CompoundOperationWrapper<MythosCandidatesInfoMapping>

    func createFetchDelegatorStakeDistribution(
        for chainId: ChainModel.Id,
        delegatorAccountId: AccountId,
        collatorIdsClosure: @escaping () throws -> [AccountId],
        blockHash: Data?
    ) -> CompoundOperationWrapper<MythosDelegatorStakeDistribution>
}

final class MythosCollatorOperationFactory {
    let chainRegistry: ChainRegistryProtocol
    let requestFactory: StorageRequestFactoryProtocol

    init(
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue,
        timeout: Int
    ) {
        self.chainRegistry = chainRegistry
        requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: operationQueue),
            timeout: timeout
        )
    }
}

extension MythosCollatorOperationFactory: MythosCollatorOperationFactoryProtocol {
    func createFetchCollatorsInfo(
        for chainId: ChainModel.Id,
        collatorIdsClosure: @escaping () throws -> [AccountId]
    ) -> CompoundOperationWrapper<MythosCandidatesInfoMapping> {
        do {
            let connection = try chainRegistry.getConnectionOrError(for: chainId)
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chainId)

            let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

            let collatorIdsListOperation = ClosureOperation<[AccountId]> {
                try collatorIdsClosure()
            }

            let candidatesWrapper: CompoundOperationWrapper<[StorageResponse<MythosStakingPallet.CandidateInfo>]>
            candidatesWrapper = requestFactory.queryItems(
                engine: connection,
                keyParams: {
                    try collatorIdsListOperation.extractNoCancellableResultData()
                },
                factory: {
                    try codingFactoryOperation.extractNoCancellableResultData()
                },
                storagePath: MythosStakingPallet.candidatesPath
            )

            candidatesWrapper.addDependency(operations: [codingFactoryOperation, collatorIdsListOperation])

            let mappingOperation = ClosureOperation<MythosCandidatesInfoMapping> {
                let candidatesResponses = try candidatesWrapper.targetOperation.extractNoCancellableResultData()
                let collatorIds = try collatorIdsListOperation.extractNoCancellableResultData()

                return zip(candidatesResponses, collatorIds).reduce(
                    into: MythosCandidatesInfoMapping()
                ) { accum, pair in
                    accum[pair.1] = pair.0.value
                }
            }

            mappingOperation.addDependency(candidatesWrapper.targetOperation)

            return candidatesWrapper
                .insertingHead(operations: [codingFactoryOperation, collatorIdsListOperation])
                .insertingTail(operation: mappingOperation)

        } catch {
            return .createWithError(error)
        }
    }

    func createFetchDelegatorStakeDistribution(
        for chainId: ChainModel.Id,
        delegatorAccountId: AccountId,
        collatorIdsClosure: @escaping () throws -> [AccountId],
        blockHash: Data?
    ) -> CompoundOperationWrapper<MythosDelegatorStakeDistribution> {
        do {
            let connection = try chainRegistry.getConnectionOrError(for: chainId)
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chainId)

            let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

            let collatorIdsListOperation = ClosureOperation<[AccountId]> {
                try collatorIdsClosure()
            }

            let stakesWrapper: CompoundOperationWrapper<[StorageResponse<MythosStakingPallet.CandidateStakeInfo>]>
            stakesWrapper = requestFactory.queryItems(
                engine: connection,
                keyParams1: {
                    let collators = try collatorIdsListOperation.extractNoCancellableResultData()

                    return collators.map { BytesCodable(wrappedValue: $0) }
                },
                keyParams2: {
                    [BytesCodable(wrappedValue: delegatorAccountId)]
                },
                factory: {
                    try codingFactoryOperation.extractNoCancellableResultData()
                },
                storagePath: MythosStakingPallet.candidateStakePath,
                at: blockHash
            )

            stakesWrapper.addDependency(operations: [codingFactoryOperation, collatorIdsListOperation])

            let mappingOperation = ClosureOperation<MythosDelegatorStakeDistribution> {
                let collators = try collatorIdsListOperation.extractNoCancellableResultData()
                let responses = try stakesWrapper.targetOperation.extractNoCancellableResultData()

                return zip(collators, responses).reduce(
                    into: MythosDelegatorStakeDistribution()
                ) { accum, pair in
                    accum[pair.0] = pair.1.value.map { info in
                        MythosStakingDetails.CollatorDetails(stake: info.stake)
                    }
                }
            }

            mappingOperation.addDependency(stakesWrapper.targetOperation)
            mappingOperation.addDependency(collatorIdsListOperation)

            return stakesWrapper
                .insertingHead(operations: [codingFactoryOperation, collatorIdsListOperation])
                .insertingTail(operation: mappingOperation)

        } catch {
            return .createWithError(error)
        }
    }
}