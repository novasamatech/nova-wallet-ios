import Operation_iOS
import SubstrateSdk
import Foundation

protocol NodePingOperationFactoryProtocol {
    func createOperation(
        for chain: ChainModel,
        connection: ChainConnection
    ) -> BaseOperation<Int>
}

class NodePingOperationFactory {
    private let storageRequestFactory: StorageRequestFactoryProtocol
    private let operationQueue: OperationQueue

    init(
        storageRequestFactory: StorageRequestFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.storageRequestFactory = storageRequestFactory
        self.operationQueue = operationQueue
    }
}

// MARK: NodePingOperationFactoryProtocol

extension NodePingOperationFactory: NodePingOperationFactoryProtocol {
    func createOperation(
        for chain: ChainModel,
        connection: ChainConnection
    ) -> BaseOperation<Int> {
        if chain.isEthereumBased, chain.noSubstrateRuntime {
            createPingMeasureOperation(
                with: createEVMQueryOperation(with: connection),
                queue: operationQueue
            )
        } else {
            createPingMeasureOperation(
                with: storageRequestFactory.queryRawItems(
                    for: {
                        let key = try StorageKeyFactory().accountInfoKeyForId(
                            AccountId.zeroAccountId(of: chain.accountIdSize)
                        )

                        return [key]
                    },
                    at: nil,
                    engine: connection
                ),
                queue: operationQueue
            )
        }
    }
}

// MARK: Private

private extension NodePingOperationFactory {
    func createEVMQueryOperation(with connection: ChainConnection) -> BaseOperation<String> {
        AsyncClosureOperation { resultClosure in
            let holder = AccountId.zeroAccountId(
                of: ChainModel.getAccountIdSize(for: .ethereum)
            ).toHex(includePrefix: true)

            let params = EvmBalanceMessage.Params(
                holder: holder,
                block: .latest
            )
            _ = try connection.callMethod(
                EvmBalanceMessage.method,
                params: params,
                options: .init(resendOnReconnect: false)
            ) { (result: Result<String, Error>) in
                switch result {
                case let .success(str):
                    resultClosure(.success(str))
                case let .failure(error):
                    resultClosure(.failure(error))
                }
            }
        }
    }

    func createPingMeasureOperation<T>(
        with queryOperation: BaseOperation<T>,
        queue: OperationQueue
    ) -> BaseOperation<Int> {
        AsyncClosureOperation { resultClosure in
            let startTime = CFAbsoluteTimeGetCurrent()
            execute(
                operation: queryOperation,
                inOperationQueue: queue,
                runningCallbackIn: nil
            ) { result in
                switch result {
                case .success:
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let ping = TimeInterval(endTime - startTime).milliseconds
                    resultClosure(.success(ping))
                case .failure:
                    resultClosure(.failure(NodePingOperationError.failedPingRequest))
                }
            }
        }
    }
}

private enum NodePingOperationError: Error {
    case failedPingRequest
}
