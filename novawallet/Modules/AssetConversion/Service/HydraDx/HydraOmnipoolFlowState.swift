import Foundation
import SubstrateSdk
import RobinHood

protocol HydraOmnipoolFlowStateProtocol {
    func setupQuoteService(for swapPair: HydraDx.SwapPair) -> HydraOmnipoolQuoteParamsService
    func setupSwapService() -> HydraOmnipoolSwapParamsService

    func getReQuoteService(
        for assetIn: ChainAssetId,
        assetOut: ChainAssetId
    ) -> ObservableSyncServiceProtocol?

    func createFeeService() throws -> AssetConversionFeeServiceProtocol
    func createExtrinsicService() throws -> AssetConversionExtrinsicServiceProtocol
}

final class HydraOmnipoolFlowState {
    let account: ChainAccountResponse
    let chain: ChainModel
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeProviderProtocol
    let userStorageFacade: StorageFacadeProtocol
    let operationQueue: OperationQueue

    let mutex = NSLock()

    private var quoteStateServices: [HydraDx.SwapPair: HydraOmnipoolQuoteParamsService] = [:]
    private var swapStateService: HydraOmnipoolSwapParamsService?

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
        swapStateService?.throttle()
    }

    private func filterQuoteServices(by assetIn: HydraDx.LocalRemoteAssetId) {
        let servicesToThrottle = quoteStateServices.filter { $0.key.assetIn != assetIn }
        servicesToThrottle.forEach { $0.value.throttle() }

        quoteStateServices = quoteStateServices.filter { $0.key.assetIn == assetIn }
    }
}

extension HydraOmnipoolFlowState: HydraOmnipoolFlowStateProtocol {
    func setupQuoteService(for swapPair: HydraDx.SwapPair) -> HydraOmnipoolQuoteParamsService {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        filterQuoteServices(by: swapPair.assetIn)

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

    func setupSwapService() -> HydraOmnipoolSwapParamsService {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if let swapStateService = swapStateService {
            return swapStateService
        }

        let service = HydraOmnipoolSwapParamsService(
            accountId: account.accountId,
            connection: connection,
            runtimeProvider: runtimeProvider,
            operationQueue: operationQueue
        )

        swapStateService = service
        service.setup()

        return service
    }

    func getReQuoteService(
        for assetIn: ChainAssetId,
        assetOut: ChainAssetId
    ) -> ObservableSyncServiceProtocol? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return quoteStateServices.first { keyValue in
            keyValue.key.assetIn.localAssetId == assetIn && keyValue.key.assetOut.localAssetId == assetOut
        }?.value
    }

    func createFeeService() throws -> AssetConversionFeeServiceProtocol {
        let extrinsicFactory = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationManager: OperationManager(operationQueue: operationQueue),
            userStorageFacade: userStorageFacade
        ).createOperationFactory(
            account: account,
            chain: chain
        )

        let conversionOperationFactory = HydraOmnipoolQuoteFactory(flowState: self)

        let swapOperationFactory = HydraOmnipoolExtrinsicOperationFactory(
            chain: chain,
            swapService: setupSwapService(),
            runtimeProvider: runtimeProvider
        )

        return HydraOmnipoolFeeService(
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
            operationManager: OperationManager(operationQueue: operationQueue),
            userStorageFacade: userStorageFacade
        ).createService(
            account: account,
            chain: chain
        )

        let operationFactory = HydraOmnipoolExtrinsicOperationFactory(
            chain: chain,
            swapService: setupSwapService(),
            runtimeProvider: runtimeProvider
        )

        return HydraOmnipoolExtrinsicService(
            extrinsicService: extrinsicService,
            conversionExtrinsicFactory: operationFactory,
            operationQueue: operationQueue
        )
    }
}
