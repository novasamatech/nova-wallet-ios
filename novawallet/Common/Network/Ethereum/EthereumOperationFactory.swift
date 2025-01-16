import Foundation
import Operation_iOS
import Keystore_iOS
import BigInt

protocol EthereumOperationFactoryProtocol {
    func createGasLimitOperation(for transaction: EthereumTransaction) -> BaseOperation<HexCodable<BigUInt>>

    func createGasPriceOperation() -> BaseOperation<HexCodable<BigUInt>>

    func createTransactionsCountOperation(
        for accountAddress: Data,
        block: EthereumBlock
    ) -> BaseOperation<HexCodable<BigUInt>>

    func createSendTransactionOperation(
        for transactionDataClosure: @escaping () throws -> Data
    ) -> BaseOperation<String>

    func createTransactionReceiptOperation(for transactionHash: String) -> BaseOperation<EthereumTransactionReceipt?>

    func createBlockOperation(for blockNumber: BigUInt) -> Operation_iOS.BaseOperation<EthereumBlockObject>

    func createReducedBlockOperation(
        for blockOption: EthereumBlock
    ) -> Operation_iOS.BaseOperation<EthereumReducedBlockObject>

    func createMaxPriorityPerGasOperation() -> BaseOperation<HexCodable<BigUInt>>

    func createChainIdOperation() -> BaseOperation<HexCodable<BigUInt>>
}

enum EthereumBlock: String {
    case latest
    case earliest
    case pending
}

enum EthereumMethod: String {
    case estimateGas = "eth_estimateGas"
    case gasPrice = "eth_gasPrice"
    case transactionCount = "eth_getTransactionCount"
    case sendRawTransaction = "eth_sendRawTransaction"
    case transactionReceipt = "eth_getTransactionReceipt"
    case blockByNumber = "eth_getBlockByNumber"
    case maxPriorityFeePerGas = "eth_maxPriorityFeePerGas"
    case chainId = "eth_chainId"
}
