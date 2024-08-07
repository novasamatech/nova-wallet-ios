import Foundation
import SubstrateSdk
import Operation_iOS

final class HydraOmnipoolFlowState {
    let account: ChainAccountResponse
    let chain: ChainModel
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeProviderProtocol
    let operationQueue: OperationQueue

    let mutex = NSLock()

    private var quoteStateServices: [HydraDx.RemoteSwapPair: HydraOmnipoolQuoteParamsService] = [:]

    init(
        account: ChainAccountResponse,
        chain: ChainModel,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        operationQueue: OperationQueue
    ) {
        self.account = account
        self.chain = chain
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.operationQueue = operationQueue
    }

    deinit {
        quoteStateServices.values.forEach { $0.throttle() }
    }
}

extension HydraOmnipoolFlowState {
    func getAllStateServices() -> [HydraOmnipoolQuoteParamsService] {
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

        quoteStateServices.values.forEach { $0.throttle() }
        quoteStateServices = [:]
    }

    func setupQuoteService(for swapPair: HydraDx.RemoteSwapPair) -> HydraOmnipoolQuoteParamsService {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if let currentService = quoteStateServices[swapPair] {
            return currentService
        }

        let newService = HydraOmnipoolQuoteParamsService(
            chain: chain,
            assetIn: swapPair.assetIn,
            assetOut: swapPair.assetOut,
            connection: connection,
            runtimeProvider: runtimeProvider,
            operationQueue: operationQueue
        )

        quoteStateServices[swapPair]?.throttle()
        quoteStateServices[swapPair] = newService

        newService.setup()

        return newService
    }
}
