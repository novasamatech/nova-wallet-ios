import Foundation
import Operation_iOS
import Web3Core
import SubstrateSdk

protocol BlockNumberToHashMapping {
    func createBlockHashMappingWrapper(for blockNumber: BlockNumber) -> CompoundOperationWrapper<Data?>
}

final class EvmBlockToSubstrateHashMapper {
    let connection: ChainConnection
    let blockHashOperationFactory: BlockHashOperationFactoryProtocol

    init(connection: ChainConnection, blockHashOperationFactory: BlockHashOperationFactoryProtocol) {
        self.connection = connection
        self.blockHashOperationFactory = blockHashOperationFactory
    }
}

extension EvmBlockToSubstrateHashMapper: BlockNumberToHashMapping {
    func createBlockHashMappingWrapper(for blockNumber: BlockNumber) -> CompoundOperationWrapper<Data?> {
        let fetchOperation = blockHashOperationFactory.createBlockHashOperation(
            connection: connection,
            for: { blockNumber }
        )

        let mapperOperation = ClosureOperation<Data?> {
            let blockHash = try fetchOperation.extractNoCancellableResultData()

            return try Data(hexString: blockHash)
        }

        mapperOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(targetOperation: mapperOperation, dependencies: [fetchOperation])
    }
}
