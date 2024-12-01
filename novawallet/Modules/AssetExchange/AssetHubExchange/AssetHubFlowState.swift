import Foundation
import SubstrateSdk
import Operation_iOS

protocol AssetHubFlowStateProtocol {
    func setupReQuoteService() -> AssetHubReQuoteService
}

final class AssetHubFlowState {
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeProviderProtocol
    let operationQueue: OperationQueue
    let notificationsRegistrar: AssetsExchangeStateRegistring

    let mutex = NSLock()

    private var reQuoteService: AssetHubReQuoteService?

    init(
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        notificationsRegistrar: AssetsExchangeStateRegistring,
        operationQueue: OperationQueue
    ) {
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.notificationsRegistrar = notificationsRegistrar
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
        
        notificationsRegistrar.registerStateService(service)
        
        return service
    }
}

extension AssetHubFlowState: AssetsExchangeStateProviding {
    func throttleStateServices() {
        mutex.lock()
        
        defer {
            mutex.unlock()
        }
        
        if let reQuoteService {
            notificationsRegistrar.deregisterStateService(reQuoteService)
            reQuoteService.throttle()
        }
        
        self.reQuoteService = nil
    }
}
