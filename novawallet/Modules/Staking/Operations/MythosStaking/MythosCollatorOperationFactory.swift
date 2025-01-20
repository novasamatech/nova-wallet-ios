import Foundation
import SubstrateSdk
import Operation_iOS

protocol MythosCollatorOperationFactoryProtocol {
    func createFetchCollatorsInfo(
        for chainId: ChainModel.Id,
        collatorIdsClosure: @escaping () throws -> Set<AccountId>
    ) -> CompoundOperationWrapper<MythosCandidatesInfoMapping>
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
        collatorIdsClosure: @escaping () throws -> Set<AccountId>
    ) -> CompoundOperationWrapper<MythosCandidatesInfoMapping> {
        do {
            let connection = try chainRegistry.getConnectionOrError(for: chainId)
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chainId)

            let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

            let collatorIdsListOperation = ClosureOperation<[AccountId]> {
                let collatorsSet = try collatorIdsClosure()
                return Array(collatorsSet)
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
}
