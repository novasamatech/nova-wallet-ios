import Foundation
import RobinHood
import SoraKeystore
import BigInt

protocol EthereumOperationFactoryProtocol {
    func createGasLimitOperation(for transaction: EthereumTransaction) -> BaseOperation<String>

    func createGasPriceOperation() -> BaseOperation<String>

    func createTransactionsCountOperation(
        for accountAddress: Data,
        block: EthereumBlock
    ) -> BaseOperation<BigUInt>

    func createSendTransactionOperation(for transactionData: Data) -> BaseOperation<Data>
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
    case sendRawTransaction = "eth_signTransaction"
}

final class EthereumOperationFactory {
    static let errorDomain = "EthereumDomain"

    let node: URL

    init(node: URL) {
        self.node = node
    }

    func createResultFactory<T: Codable>() -> AnyNetworkResultFactory<T> {
        AnyNetworkResultFactory { data in
            let response = try JSONDecoder().decode(EthereumRpcResponse<T>.self, from: data)

            if let result = response.result {
                return result
            }

            if let error = response.error {
                throw NSError(
                    domain: Self.errorDomain,
                    code: error.code,
                    userInfo: [NSLocalizedDescriptionKey: error.message]
                )
            }

            throw BaseOperationError.unexpectedDependentResult
        }
    }
}
