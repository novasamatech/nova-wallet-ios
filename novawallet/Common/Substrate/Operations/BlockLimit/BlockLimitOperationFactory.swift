import Foundation
import Operation_iOS
import SubstrateSdk

protocol BlockLimitOperationFactoryProtocol {
    func fetchBlockWeights(for chainId: ChainModel.Id) -> CompoundOperationWrapper<Substrate.BlockWeights>

    func fetchLastBlockWeight(
        for chainId: ChainModel.Id
    ) -> CompoundOperationWrapper<Substrate.PerDispatchClassWithWeight>
}

final class BlockLimitOperationFactory {
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue

    init(chainRegistry: ChainRegistryProtocol, operationQueue: OperationQueue) {
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
    }
}

extension BlockLimitOperationFactory: BlockLimitOperationFactoryProtocol {
    func fetchBlockWeights(for chainId: ChainModel.Id) -> CompoundOperationWrapper<Substrate.BlockWeights> {
        do {
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chainId)

            let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

            let blockWeightsOperation = StorageConstantOperation<Substrate.BlockWeights>(
                path: SystemPallet.blockWeights
            )

            blockWeightsOperation.configurationBlock = {
                do {
                    blockWeightsOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
                } catch {
                    blockWeightsOperation.result = .failure(error)
                }
            }

            blockWeightsOperation.addDependency(codingFactoryOperation)

            return CompoundOperationWrapper(
                targetOperation: blockWeightsOperation,
                dependencies: [codingFactoryOperation]
            )
        } catch {
            return .createWithError(error)
        }
    }

    func fetchLastBlockWeight(
        for chainId: ChainModel.Id
    ) -> CompoundOperationWrapper<Substrate.PerDispatchClassWithWeight> {
        do {
            let requestFactory = StorageRequestFactory(
                remoteFactory: StorageKeyFactory(),
                operationManager: OperationManager(operationQueue: operationQueue)
            )

            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chainId)
            let connection = try chainRegistry.getConnectionOrError(for: chainId)

            let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

            let queryWrapper: CompoundOperationWrapper<StorageResponse<Substrate.PerDispatchClassWithWeight>>
            queryWrapper = requestFactory.queryItem(
                engine: connection,
                factory: {
                    try codingFactoryOperation.extractNoCancellableResultData()
                },
                storagePath: SystemPallet.blockWeightPath
            )

            queryWrapper.addDependency(operations: [codingFactoryOperation])

            let mappingOperation = ClosureOperation<Substrate.PerDispatchClassWithWeight> {
                guard let response = try queryWrapper.targetOperation.extractNoCancellableResultData().value else {
                    throw CommonError.noDataRetrieved
                }

                return response
            }

            mappingOperation.addDependency(queryWrapper.targetOperation)

            return queryWrapper
                .insertingHead(operations: [codingFactoryOperation])
                .insertingTail(operation: mappingOperation)
        } catch {
            return .createWithError(error)
        }
    }
}
