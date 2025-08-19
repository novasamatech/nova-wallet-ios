import Foundation
import SubstrateSdk
import Operation_iOS

final class HydraAaveFlowState {
    let account: ChainAccountResponse
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeProviderProtocol
    let operationQueue: OperationQueue
    let workingQueue: DispatchQueue
    let notificationsRegistrar: AssetsExchangeStateRegistring?
    let apiFactory: HydraAaveTradeExecutorFactoryProtocol
    let logger: LoggerProtocol

    let mutex = NSLock()

    private var quoteStateServices: [HydraDx.RemoteSwapPair: HydraAaveQuoteParamsService] = [:]
    private var poolsService: (any HydraAavePoolsServiceProtocol)?

    init(
        account: ChainAccountResponse,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        notificationsRegistrar: AssetsExchangeStateRegistring?,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue = .global(),
        logger: LoggerProtocol = Logger.shared
    ) {
        self.account = account
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.notificationsRegistrar = notificationsRegistrar
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue
        self.logger = logger

        apiFactory = HydraAaveTradeExecutorFactory(
            connection: connection,
            runtimeProvider: runtimeProvider,
            operationQueue: operationQueue
        )
    }

    deinit {
        clear()
    }
}

private extension HydraAaveFlowState {
    func clear() {
        quoteStateServices.values.forEach {
            notificationsRegistrar?.deregisterStateService($0)
            $0.throttle()
        }

        quoteStateServices = [:]

        poolsService?.throttle()
        poolsService = nil
    }

    func setupPoolsServiceIfNeeded() -> any HydraAavePoolsServiceProtocol {
        if let poolsService {
            return poolsService
        }

        let pollingState = ChainPollingStateStore(
            runtimeConnectionStore: StaticRuntimeConnectionStore(
                connection: connection,
                runtimeProvider: runtimeProvider
            ),
            operationQueue: operationQueue,
            workQueue: workingQueue,
            logger: logger
        )

        let service = HydraAavePoolsService(
            trigger: pollingState,
            apiFactory: apiFactory,
            operationQueue: operationQueue,
            workingQueue: workingQueue,
            logger: logger
        )

        poolsService = service

        pollingState.setup()
        service.setup()

        return service
    }
}

extension HydraAaveFlowState {
    // TODO: Consider to remove
    func getAllStateServices() -> [HydraAaveQuoteParamsService] {
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

        clear()
    }

    func setupQuoteService(for swapPair: HydraDx.RemoteSwapPair) -> HydraAaveQuoteParamsService {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if let currentService = quoteStateServices[swapPair] {
            return currentService
        }

        let poolsService = setupPoolsServiceIfNeeded()

        let newService = HydraAaveQuoteParamsService(
            swapPair: swapPair,
            poolsService: poolsService,
            workingQueue: workingQueue
        )

        quoteStateServices[swapPair] = newService

        newService.setup()

        notificationsRegistrar?.registerStateService(newService)

        return newService
    }
}

extension HydraAaveFlowState: AssetsExchangeStateProviding {
    func throttleStateServices() {
        resetServices()
    }
}
