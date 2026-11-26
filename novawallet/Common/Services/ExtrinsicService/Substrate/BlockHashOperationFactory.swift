import Foundation
import Operation_iOS
import SubstrateSdk

protocol BlockHashOperationFactoryProtocol {
    func createBlockHashOperation(
        connection: JSONRPCEngine,
        for numberClosure: @escaping () throws -> BlockNumber
    ) -> BaseOperation<String>

    func createBlockHashOperation(
        connection: JSONRPCEngine,
        timeout: Int,
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

        return configure(requestOperation, numberClosure: numberClosure)
    }

    func createBlockHashOperation(
        connection: JSONRPCEngine,
        timeout: Int,
        for numberClosure: @escaping () throws -> BlockNumber
    ) -> BaseOperation<String> {
        let requestOperation = JSONRPCListOperation<String>(
            engine: connection,
            method: RPCMethod.getBlockHash,
            timeout: timeout
        )

        return configure(requestOperation, numberClosure: numberClosure)
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

private extension BlockHashOperationFactory {
    func configure(
        _ requestOperation: JSONRPCListOperation<String>,
        numberClosure: @escaping () throws -> BlockNumber
    ) -> BaseOperation<String> {
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
}
