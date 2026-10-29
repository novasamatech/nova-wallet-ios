import Foundation
import Operation_iOS
import SubstrateSdk

protocol FinalizedHeaderOperationFactoryProtocol {
    func createHeaderWrapper(from connection: JSONRPCEngine) -> CompoundOperationWrapper<Block.Header>

    func createBlockNumberWrapper(from connection: JSONRPCEngine) -> CompoundOperationWrapper<BlockNumber>
}

final class FinalizedHeaderOperationFactory {}

extension FinalizedHeaderOperationFactory: FinalizedHeaderOperationFactoryProtocol {
    func createHeaderWrapper(from connection: JSONRPCEngine) -> CompoundOperationWrapper<Block.Header> {
        let hashOperation = JSONRPCListOperation<String>(
            engine: connection,
            method: RPCMethod.getFinalizedBlockHash
        )

        let headerOperation = JSONRPCListOperation<Block.Header>(
            engine: connection,
            method: RPCMethod.getBlockHeader
        )

        headerOperation.configurationBlock = {
            do {
                headerOperation.parameters = [try hashOperation.extractNoCancellableResultData()]
            } catch {
                headerOperation.result = .failure(error)
            }
        }

        headerOperation.addDependency(hashOperation)

        return CompoundOperationWrapper(targetOperation: headerOperation, dependencies: [hashOperation])
    }

    func createBlockNumberWrapper(from connection: JSONRPCEngine) -> CompoundOperationWrapper<BlockNumber> {
        BlockNumberOperationFactory.createWrapper(for: createHeaderWrapper(from: connection))
    }
}
