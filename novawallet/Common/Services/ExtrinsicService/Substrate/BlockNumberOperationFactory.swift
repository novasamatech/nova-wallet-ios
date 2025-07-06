import Foundation
import Operation_iOS
import SubstrateSdk

protocol BlockNumberOperationFactoryProtocol {
    func createWrapper(
        for chainId: ChainModel.Id,
        blockHash: Data?
    ) -> CompoundOperationWrapper<BlockNumber>
}

extension BlockNumberOperationFactoryProtocol {
    func createWrapper(for chainId: ChainModel.Id) -> CompoundOperationWrapper<BlockNumber> {
        createWrapper(for: chainId, blockHash: nil)
    }
}

enum BlockNumberOperationFactoryError: Error {
    case missingBlock
}

final class BlockNumberOperationFactory {
    let chainRegistry: ChainRegistryProtocol
    let storageRequestFactory: StorageRequestFactoryProtocol

    init(chainRegistry: ChainRegistryProtocol, operationQueue: OperationQueue) {
        self.chainRegistry = chainRegistry
        storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )
    }
}

extension BlockNumberOperationFactory: BlockNumberOperationFactoryProtocol {
    func createWrapper(for chainId: ChainModel.Id, blockHash: Data?) -> CompoundOperationWrapper<BlockNumber> {
        do {
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chainId)
            let connection = try chainRegistry.getConnectionOrError(for: chainId)

            let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

            let wrapper: CompoundOperationWrapper<StorageResponse<StringCodable<BlockNumber>>>

            wrapper = storageRequestFactory.queryItem(
                engine: connection,
                factory: {
                    try codingFactoryOperation.extractNoCancellableResultData()
                },
                storagePath: SystemPallet.blockNumberPath,
                at: blockHash
            )

            wrapper.addDependency(operations: [codingFactoryOperation])

            let mapOperation = ClosureOperation<BlockNumber> {
                let optBlockNumber = try wrapper.targetOperation.extractNoCancellableResultData().value

                guard let blockNumber = optBlockNumber?.wrappedValue else {
                    throw BlockNumberOperationFactoryError.missingBlock
                }

                return blockNumber
            }

            mapOperation.addDependency(wrapper.targetOperation)

            return wrapper
                .insertingHead(operations: [codingFactoryOperation])
                .insertingTail(operation: mapOperation)
        } catch {
            return .createWithError(error)
        }
    }
}
