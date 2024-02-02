import Foundation
import SubstrateSdk

protocol AssetHubFlowStateProtocol {
    func setupReQuoteService() -> AssetHubReQuoteService
}

final class AssetHubFlowState {
    let chain: ChainModel
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeCodingServiceProtocol
    let operationQueue: OperationQueue

    let mutex = NSLock()

    private var reQuoteService: AssetHubReQuoteService?

    init(
        chain: ChainModel,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue
    ) {
        self.chain = chain
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.operationQueue = operationQueue
    }
}

extension AssetHubFlowState: AssetHubFlowStateProtocol {
    func setupReQuoteService() -> AssetHubReQuoteService {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if let reQuoteService = reQuoteService {
            return reQuoteService
        }

        let service = AssetHubReQuoteService(
            connection: connection,
            runtimeProvider: runtimeProvider,
            operationQueue: operationQueue
        )

        reQuoteService = service
        service.setup()

        return service
    }
}
