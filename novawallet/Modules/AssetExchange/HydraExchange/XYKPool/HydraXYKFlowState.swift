import Foundation
import SubstrateSdk
import Operation_iOS

final class HydraXYKFlowState {
    let account: ChainAccountResponse
    let chain: ChainModel
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeProviderProtocol
    let operationQueue: OperationQueue
    let notificationsRegistrar: AssetsExchangeStateRegistring
    
    let mutex = NSLock()

    private var quoteStateServices: [HydraDx.RemoteSwapPair: HydraXYKQuoteParamsService] = [:]

    init(
        account: ChainAccountResponse,
        chain: ChainModel,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        notificationsRegistrar: AssetsExchangeStateRegistring,
        operationQueue: OperationQueue
    ) {
        self.account = account
        self.chain = chain
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.notificationsRegistrar = notificationsRegistrar
        self.operationQueue = operationQueue
    }

    deinit {
        quoteStateServices.values.forEach {
            notificationsRegistrar.deregisterStateService($0)
            $0.throttle()
        }
    }
}

extension HydraXYKFlowState {
    func getAllStateServices() -> [HydraXYKQuoteParamsService] {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return Array(quoteStateServices.values)
    }

    func resetServices() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        quoteStateServices.values.forEach {
            notificationsRegistrar.deregisterStateService($0)
            $0.throttle()
        }
        
        quoteStateServices = [:]
    }

    func setupQuoteService(for swapPair: HydraDx.RemoteSwapPair) -> HydraXYKQuoteParamsService {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if let currentService = quoteStateServices[swapPair] {
            return currentService
        }

        let newService = HydraXYKQuoteParamsService(
            chain: chain,
            assetIn: swapPair.assetIn,
            assetOut: swapPair.assetOut,
            connection: connection,
            runtimeProvider: runtimeProvider,
            operationQueue: operationQueue
        )

        quoteStateServices[swapPair] = newService

        newService.setup()
        
        notificationsRegistrar.registerStateService(newService)

        return newService
    }
}

extension HydraXYKFlowState: AssetsExchangeStateProviding {
    func throttleStateServices() {
        resetServices()
    }
}
