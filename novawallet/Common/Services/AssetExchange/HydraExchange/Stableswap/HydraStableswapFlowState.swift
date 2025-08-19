import Foundation
import SubstrateSdk
import Operation_iOS

final class HydraStableswapFlowState {
    let account: ChainAccountResponse
    let chain: ChainModel
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeProviderProtocol
    let operationQueue: OperationQueue
    let notificationsRegistrar: AssetsExchangeStateRegistring?

    let mutex = NSLock()

    private var quoteStateServices: [HydraStableswap.PoolPair: HydraStableswapQuoteParamsService] = [:]

    init(
        account: ChainAccountResponse,
        chain: ChainModel,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        notificationsRegistrar: AssetsExchangeStateRegistring?,
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
            notificationsRegistrar?.deregisterStateService($0)
            $0.throttle()
        }
    }
}

extension HydraStableswapFlowState {
    func resetServices() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        quoteStateServices.values.forEach {
            notificationsRegistrar?.deregisterStateService($0)
            $0.throttle()
        }

        quoteStateServices = [:]
    }

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

        quoteStateServices[poolPair] = newService

        newService.setup()

        notificationsRegistrar?.registerStateService(newService)

        return newService
    }
}

extension HydraStableswapFlowState: AssetsExchangeStateProviding {
    func throttleStateServices() {
        resetServices()
    }
}
