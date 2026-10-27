import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

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
        let headerWrapper = createHeaderWrapper(from: connection)

        let numberOperation = ClosureOperation<BlockNumber> {
            let header = try headerWrapper.targetOperation.extractNoCancellableResultData()

            guard
                let number = BigUInt.fromHexString(header.number),
                let blockNumber = BlockNumber(exactly: number) else {
                throw BaseOperationError.unexpectedDependentResult
            }

            return blockNumber
        }

        numberOperation.addDependency(headerWrapper.targetOperation)

        return headerWrapper.insertingTail(operation: numberOperation)
    }
}
