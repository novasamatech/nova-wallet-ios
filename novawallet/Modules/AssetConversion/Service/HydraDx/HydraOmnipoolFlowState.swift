import Foundation
import SubstrateSdk

protocol HydraOmnipoolFlowStateProtocol {
    func setupQuoteService(for swapPair: HydraDx.SwapPair) -> HydraOmnipoolQuoteService
    func setupSwapService() -> HydraOmnipoolSwapService
}

final class HydraOmnipoolFlowState {
    let account: ChainAccountResponse
    let chain: ChainModel
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeCodingServiceProtocol
    let operationQueue: OperationQueue

    let mutex = NSLock()

    private var quoteStateService: HydraOmnipoolQuoteService?
    private var swapStateService: HydraOmnipoolSwapService?

    init(
        account: ChainAccountResponse,
        chain: ChainModel,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue
    ) {
        self.account = account
        self.chain = chain
        self.connection = connection
        self.runtimeProvider = runtimeProvider
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
}
