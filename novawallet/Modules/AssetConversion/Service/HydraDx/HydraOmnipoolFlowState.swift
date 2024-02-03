import Foundation
import SubstrateSdk
import RobinHood

protocol HydraOmnipoolFlowStateProtocol {
    func setupQuoteService(for swapPair: HydraDx.SwapPair) -> HydraOmnipoolQuoteService
    func setupSwapService() -> HydraOmnipoolSwapService

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

    private var quoteStateService: HydraOmnipoolQuoteService?
    private var swapStateService: HydraOmnipoolSwapService?

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
        quoteStateService?.throttle()
        swapStateService?.throttle()
    }
}

extension HydraOmnipoolFlowState: HydraOmnipoolFlowStateProtocol {
    func setupQuoteService(for swapPair: HydraDx.SwapPair) -> HydraOmnipoolQuoteService {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if
            let currentService = quoteStateService,
            currentService.assetIn == swapPair.assetIn,
            currentService.assetOut == swapPair.assetOut {
            return currentService
        }

        let newService = HydraOmnipoolQuoteService(
            chain: chain,
            assetIn: swapPair.assetIn,
            assetOut: swapPair.assetOut,
            connection: connection,
            runtimeProvider: runtimeProvider,
            operationQueue: operationQueue
        )

        quoteStateService?.throttle()

        quoteStateService = newService
        quoteStateService?.setup()

        return newService
    }

    func setupSwapService() -> HydraOmnipoolSwapService {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if let swapStateService = swapStateService {
            return swapStateService
        }

        let service = HydraOmnipoolSwapService(
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
