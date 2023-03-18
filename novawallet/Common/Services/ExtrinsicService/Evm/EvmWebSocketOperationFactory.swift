import Foundation
import RobinHood
import SubstrateSdk
import BigInt

final class EvmWebSocketOperationFactory {
    let connection: JSONRPCEngine
    let timeout: Int

    init(connection: JSONRPCEngine, timeout: Int = 60) {
        self.connection = connection
        self.timeout = timeout
    }
}

extension EvmWebSocketOperationFactory: EthereumOperationFactoryProtocol {
    func createBlockOperation(for blockNumber: BigUInt) -> RobinHood.BaseOperation<EthereumBlockObject> {
        let parameters = [blockNumber.toHexString()]

        return JSONRPCListOperation(
            engine: connection,
            method: EthereumMethod.blockByNumber.rawValue,
            parameters: parameters,
            timeout: timeout
        )
    }

    func createTransactionReceiptOperation(
        for transactionHash: String
    ) -> RobinHood.BaseOperation<EthereumTransactionReceipt?> {
        let parameters = [transactionHash]

        return JSONRPCListOperation(
            engine: connection,
            method: EthereumMethod.transactionReceipt.rawValue,
            parameters: parameters,
            timeout: timeout
        )
    }

    func createGasLimitOperation(for transaction: EthereumTransaction) -> BaseOperation<String> {
        JSONRPCOperation<[EthereumTransaction], String>(
            engine: connection,
            method: EthereumMethod.estimateGas.rawValue,
            parameters: [transaction],
            timeout: timeout
        )
    }

    func createGasPriceOperation() -> BaseOperation<String> {
        JSONRPCListOperation(
            engine: connection,
            method: EthereumMethod.gasPrice.rawValue,
            parameters: [],
            timeout: timeout
        )
    }

    func createTransactionsCountOperation(for accountAddress: Data, block: EthereumBlock) -> BaseOperation<String> {
        let parameters = [accountAddress.toHex(includePrefix: true), block.rawValue]

        return JSONRPCListOperation(
            engine: connection,
            method: EthereumMethod.transactionCount.rawValue,
            parameters: parameters,
            timeout: timeout
        )
    }

    func createSendTransactionOperation(
        for transactionDataClosure: @escaping () throws -> Data
    ) -> BaseOperation<String> {
        let operation = JSONRPCListOperation<String>(
            engine: connection,
            method: EthereumMethod.sendRawTransaction.rawValue,
            timeout: timeout
        )

        operation.configurationBlock = {
            do {
                let txData = try transactionDataClosure()
                operation.parameters = [txData.toHex(includePrefix: true)]
            } catch {
                operation.result = .failure(error)
            }
        }

        return operation
    }
}
