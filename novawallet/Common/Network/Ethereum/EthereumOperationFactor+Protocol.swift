import Foundation
import RobinHood
import BigInt
import SubstrateSdk

extension EthereumOperationFactory: EthereumOperationFactoryProtocol {
    func createGasLimitOperation(for transaction: EthereumTransaction) -> BaseOperation<String> {
        let url = node

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.post.rawValue

            let method = EthereumMethod.estimateGas.rawValue
            let jsonRequest = EthereumRpcRequest(method: method, params: [transaction])

            request.httpBody = try JSONEncoder().encode(jsonRequest)
            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )

            return request
        }

        let resultFactory: AnyNetworkResultFactory<String> = createResultFactory()

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    func createGasPriceOperation() -> BaseOperation<String> {
        let url = node

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.post.rawValue

            let method = EthereumMethod.gasPrice.rawValue
            let jsonRequest = EthereumRpcRequest(method: method)

            request.httpBody = try JSONEncoder().encode(jsonRequest)
            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )

            return request
        }

        let resultFactory: AnyNetworkResultFactory<String> = createResultFactory()

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    func createTransactionsCountOperation(
        for accountAddress: Data,
        block: EthereumBlock
    ) -> BaseOperation<String> {
        let url = node

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.post.rawValue

            let parameters = [accountAddress.toHex(includePrefix: true), block.rawValue]

            let method = EthereumMethod.transactionCount.rawValue
            let jsonRequest = EthereumRpcRequest(method: method, params: parameters)
            request.httpBody = try JSONEncoder().encode(jsonRequest)
            request.setValue(HttpContentType.json.rawValue, forHTTPHeaderField: HttpHeaderKey.contentType.rawValue)

            return request
        }

        let resultFactory: AnyNetworkResultFactory<String> = createResultFactory()

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    func createSendTransactionOperation(
        for transactionDataClosure: @escaping () throws -> Data
    ) -> BaseOperation<String> {
        let url = node

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.post.rawValue

            let method = EthereumMethod.sendRawTransaction.rawValue
            let param = try transactionDataClosure().toHex(includePrefix: true)
            let jsonRequest = EthereumRpcRequest(method: method, params: [param])
            request.httpBody = try JSONEncoder().encode(jsonRequest)
            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )

            return request
        }

        let resultFactory: AnyNetworkResultFactory<String> = createResultFactory()

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }
}
