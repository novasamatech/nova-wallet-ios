import Foundation
import Operation_iOS
import SubstrateSdk

protocol BlockHashOperationFactoryProtocol {
    func createBlockHashOperation(
        connection: JSONRPCEngine,
        for numberClosure: @escaping () throws -> BlockNumber
    ) -> BaseOperation<String>

    func createBestBlockHashWrapper(
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<BlockHashData>
}

class BlockHashOperationFactory: BlockHashOperationFactoryProtocol {
    func createBlockHashOperation(
        connection: JSONRPCEngine,
        for numberClosure: @escaping () throws -> BlockNumber
    ) -> BaseOperation<String> {
        let requestOperation = JSONRPCListOperation<String>(
            engine: connection,
            method: RPCMethod.getBlockHash
        )

        requestOperation.configurationBlock = {
            do {
                let blockNumber = try numberClosure()
                requestOperation.parameters = [blockNumber.toHex()]
            } catch {
                requestOperation.result = .failure(error)
            }
        }

        return requestOperation
    }

    func createBestBlockHashWrapper(
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<BlockHashData> {
        let requestOperation = JSONRPCListOperation<String>(
            engine: connection,
            method: RPCMethod.getBlockHash
        )

        let mapOperation = ClosureOperation<BlockHashData> {
            let hexHash = try requestOperation.extractNoCancellableResultData()

            return try Data(hexString: hexHash)
        }

        mapOperation.addDependency(requestOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [requestOperation]
        )
    }
}
