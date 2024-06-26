import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

final class EvmWebSocketOperationFactory {
    let connection: JSONRPCEngine
    let timeout: Int

    init(connection: JSONRPCEngine, timeout: Int = JSONRPCTimeout.singleNode) {
        self.connection = connection
        self.timeout = timeout
    }
}

extension EvmWebSocketOperationFactory: EthereumOperationFactoryProtocol {
    func createBlockOperation(for blockNumber: BigUInt) -> Operation_iOS.BaseOperation<EthereumBlockObject> {
        let blockNumberString = blockNumber.toHexString()

        let params = JSON.arrayValue(
            [
                JSON.stringValue(blockNumberString), // block number
                JSON.boolValue(true) // should return full transactions
            ]
        )

        return JSONRPCOperation(
            engine: connection,
            method: EthereumMethod.blockByNumber.rawValue,
            parameters: params,
            timeout: timeout
        )
    }

    func createTransactionReceiptOperation(
        for transactionHash: String
    ) -> Operation_iOS.BaseOperation<EthereumTransactionReceipt?> {
        let parameters = [transactionHash]

        return JSONRPCListOperation(
            engine: connection,
            method: EthereumMethod.transactionReceipt.rawValue,
            parameters: parameters,
            timeout: timeout
        )
    }

    func createGasLimitOperation(for transaction: EthereumTransaction) -> BaseOperation<HexCodable<BigUInt>> {
        JSONRPCOperation<[EthereumTransaction], HexCodable<BigUInt>>(
            engine: connection,
            method: EthereumMethod.estimateGas.rawValue,
            parameters: [transaction],
            timeout: timeout
        )
    }

    func createGasPriceOperation() -> BaseOperation<HexCodable<BigUInt>> {
        JSONRPCListOperation(
            engine: connection,
            method: EthereumMethod.gasPrice.rawValue,
            parameters: [],
            timeout: timeout
        )
    }

    func createTransactionsCountOperation(
        for accountAddress: Data,
        block: EthereumBlock
    ) -> BaseOperation<HexCodable<BigUInt>> {
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

    func createReducedBlockOperation(
        for blockOption: EthereumBlock
    ) -> Operation_iOS.BaseOperation<EthereumReducedBlockObject> {
        let params = JSON.arrayValue(
            [
                JSON.stringValue(blockOption.rawValue), // block number
                JSON.boolValue(false) // should return full transactions
            ]
        )

        return JSONRPCOperation<JSON, EthereumReducedBlockObject>(
            engine: connection,
            method: EthereumMethod.blockByNumber.rawValue,
            parameters: params,
            timeout: timeout
        )
    }

    func createMaxPriorityPerGasOperation() -> BaseOperation<HexCodable<BigUInt>> {
        JSONRPCListOperation<HexCodable<BigUInt>>(
            engine: connection,
            method: EthereumMethod.maxPriorityFeePerGas.rawValue,
            parameters: [],
            timeout: timeout
        )
    }
    
    func createChainIdOperation() -> BaseOperation<HexCodable<BigUInt>> {
        return JSONRPCOperation(
            engine: connection,
            method: EthereumMethod.chainId.rawValue,
            parameters: JSON.arrayValue([]),
            timeout: timeout
        )
    }
}
