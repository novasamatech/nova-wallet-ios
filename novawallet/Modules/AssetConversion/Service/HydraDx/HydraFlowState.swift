import Foundation
import SubstrateSdk
import Operation_iOS

protocol HydraFlowStateProtocol {
    func getReQuoteService(
        for assetIn: ChainAssetId,
        assetOut: ChainAssetId
    ) -> ObservableSyncServiceProtocol?

    func createFeeService() throws -> AssetConversionFeeServiceProtocol
    func createExtrinsicService() throws -> AssetConversionExtrinsicServiceProtocol
}

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
    private var reQuoteService: HydraReQuoteService?
    private var swapStateService: HydraSwapParamsService?
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

    deinit {
        reQuoteService?.throttle()
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

        reQuoteService?.throttle()
        reQuoteService = nil

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
            operationQueue: operationQueue
        )

        xykswapFlowState = newState

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

    func getReQuoteService(
        for assetIn: ChainAssetId,
        assetOut: ChainAssetId
    ) -> ObservableSyncServiceProtocol? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        let swapPair = HydraDx.LocalSwapPair(assetIn: assetIn, assetOut: assetOut)

        guard currentSwapPair == swapPair else {
            return nil
        }

        if let reQuoteService = reQuoteService {
            return reQuoteService
        }

        let services: [ObservableSyncServiceProtocol] = (omnipoolFlowState?.getAllStateServices() ?? []) +
            (stableswapFlowState?.getAllStateServices() ?? []) +
            (xykswapFlowState?.getAllStateServices() ?? [])

        let reQuoteService = HydraReQuoteService(childServices: services)
        self.reQuoteService = reQuoteService

        reQuoteService.setup()

        return reQuoteService
    }

    func setupSwapService() -> HydraSwapParamsService {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if let swapStateService = swapStateService {
            return swapStateService
        }

        let service = HydraSwapParamsService(
            accountId: account.accountId,
            connection: connection,
            runtimeProvider: runtimeProvider,
            operationQueue: operationQueue
        )

        swapStateService = service
        service.setup()

        return service
    }

    func createFeeService() throws -> AssetConversionFeeServiceProtocol {
        let extrinsicFactory = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationQueue: operationQueue,
            userStorageFacade: userStorageFacade,
            substrateStorageFacade: substrateStorageFacade
        ).createOperationFactory(
            account: account,
            chain: chain
        )

        let conversionOperationFactory = HydraQuoteFactory(flowState: self)

        let swapOperationFactory = HydraExtrinsicOperationFactory(
            chain: chain,
            swapService: setupSwapService(),
            runtimeProvider: runtimeProvider
        )

        return HydraFeeService(
            extrinsicFactory: extrinsicFactory,
            conversionOperationFactory: conversionOperationFactory,
            conversionExtrinsicFactory: swapOperationFactory,
            operationQueue: operationQueue
        )
    }

    func createExtrinsicService() throws -> AssetConversionExtrinsicServiceProtocol {
        let extrinsicService = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationQueue: operationQueue,
            userStorageFacade: userStorageFacade,
            substrateStorageFacade: substrateStorageFacade
        ).createService(
            account: account,
            chain: chain
        )

        let operationFactory = HydraExtrinsicOperationFactory(
            chain: chain,
            swapService: setupSwapService(),
            runtimeProvider: runtimeProvider
        )

        return HydraExtrinsicService(
            extrinsicService: extrinsicService,
            conversionExtrinsicFactory: operationFactory,
            operationQueue: operationQueue
        )
    }
}
