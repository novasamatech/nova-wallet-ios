import Foundation
import SubstrateSdk
import RobinHood

final class HydraStableswapFlowState {
    let account: ChainAccountResponse
    let chain: ChainModel
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeProviderProtocol
    let userStorageFacade: StorageFacadeProtocol
    let operationQueue: OperationQueue

    let mutex = NSLock()

    private var quoteStateServices: [HydraStableswap.PoolPair: HydraStableswapQuoteParamsService] = [:]

    init(
        account: ChainAccountResponse,
        chain: ChainModel,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        userStorageFacade: StorageFacadeProtocol,
        operationQueue: OperationQueue
    ) {
        self.account = account
        self.chain = chain
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.userStorageFacade = userStorageFacade
        self.operationQueue = operationQueue
    }

    deinit {
        quoteStateServices.values.forEach { $0.throttle() }
    }
}

extension HydraStableswapFlowState {
    func setupQuoteService(
        for poolPair: HydraStableswap.PoolPair
    ) -> HydraStableswapQuoteParamsService {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if let currentService = quoteStateServices[poolPair] {
            return currentService
        }

        let newService = HydraStableswapQuoteParamsService(
            userAccountId: account.accountId,
            poolAsset: poolPair.poolAsset,
            assetIn: poolPair.assetIn,
            assetOut: poolPair.assetOut,
            connection: connection,
            runtimeProvider: runtimeProvider,
            operationQueue: operationQueue
        )

        quoteStateServices[poolPair]?.throttle()
        quoteStateServices[poolPair] = newService

        newService.setup()

        return newService
    }
}
