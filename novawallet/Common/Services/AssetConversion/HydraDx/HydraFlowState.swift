import Foundation
import SubstrateSdk
import Operation_iOS

final class HydraFlowState {
    let account: ChainAccountResponse
    let chain: ChainModel
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeProviderProtocol
    let userStorageFacade: StorageFacadeProtocol
    let substrateStorageFacade: StorageFacadeProtocol
    let operationQueue: OperationQueue

    let mutex = NSLock()

    private var omnipoolFlowState: HydraOmnipoolFlowState?
    private var stableswapFlowState: HydraStableswapFlowState?
    private var xykswapFlowState: HydraXYKFlowState?
    private var aaveFlowState: HydraAaveFlowState?
    private var routesFactory: HydraRoutesOperationFactoryProtocol?

    private var currentSwapPair: HydraDx.LocalSwapPair?

    init(
        account: ChainAccountResponse,
        chain: ChainModel,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        userStorageFacade: StorageFacadeProtocol,
        substrateStorageFacade: StorageFacadeProtocol,
        operationQueue: OperationQueue
    ) {
        self.account = account
        self.chain = chain
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.userStorageFacade = userStorageFacade
        self.substrateStorageFacade = substrateStorageFacade
        self.operationQueue = operationQueue
    }
}

extension HydraFlowState {
    func resetServicesIfNotMatchingPair(_ swapPair: HydraDx.LocalSwapPair) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard swapPair != currentSwapPair else {
            return
        }

        omnipoolFlowState?.resetServices()
        stableswapFlowState?.resetServices()
        xykswapFlowState?.resetServices()

        routesFactory = nil

        currentSwapPair = swapPair
    }

    func getOmnipoolFlowState() -> HydraOmnipoolFlowState {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if let state = omnipoolFlowState {
            return state
        }

        let newState = HydraOmnipoolFlowState(
            account: account,
            chain: chain,
            connection: connection,
            runtimeProvider: runtimeProvider,
            notificationsRegistrar: nil,
            operationQueue: operationQueue
        )

        omnipoolFlowState = newState

        return newState
    }

    func getStableswapFlowState() -> HydraStableswapFlowState {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if let state = stableswapFlowState {
            return state
        }

        let newState = HydraStableswapFlowState(
            account: account,
            chain: chain,
            connection: connection,
            runtimeProvider: runtimeProvider,
            notificationsRegistrar: nil,
            operationQueue: operationQueue
        )

        stableswapFlowState = newState

        return newState
    }

    func getXYKSwapFlowState() -> HydraXYKFlowState {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if let state = xykswapFlowState {
            return state
        }

        let newState = HydraXYKFlowState(
            account: account,
            chain: chain,
            connection: connection,
            runtimeProvider: runtimeProvider,
            notificationsRegistrar: nil,
            operationQueue: operationQueue
        )

        xykswapFlowState = newState

        return newState
    }

    func getAaveSwapFlowState() -> HydraAaveFlowState {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if let state = aaveFlowState {
            return state
        }

        let newState = HydraAaveFlowState(
            account: account,
            connection: connection,
            runtimeProvider: runtimeProvider,
            notificationsRegistrar: nil,
            operationQueue: operationQueue
        )

        aaveFlowState = newState

        return newState
    }

    func getRoutesFactory() -> HydraRoutesOperationFactoryProtocol {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if let factory = routesFactory {
            return factory
        }

        let factory = HydraRoutesOperationFactory(
            chain: chain,
            connection: connection,
            runtimeProvider: runtimeProvider,
            operationQueue: operationQueue
        )

        routesFactory = factory

        return factory
    }
}
