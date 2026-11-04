import Foundation
import SubstrateSdk
import Operation_iOS

final class HydraAaveFlowState {
    // the Hydration graph waits for every venue, so this bounds how long Aave can hold Omnipool/XYK routes
    static let defaultDiscoveryTimeLimit: TimeInterval = 30

    let account: ChainAccountResponse
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeProviderProtocol
    let operationQueue: OperationQueue
    let workingQueue: DispatchQueue
    let notificationsRegistrar: AssetsExchangeStateRegistring?
    let apiFactory: HydraAaveTradeExecutorFactoryProtocol
    let reservesDiscoveryFactory: HydraAaveReservesDiscoveryFactoryProtocol
    let discoveryTimeLimit: TimeInterval
    let logger: LoggerProtocol

    let mutex = NSLock()

    private var quoteStateServices: [HydraDx.RemoteSwapPair: HydraAaveQuoteParamsService] = [:]
    private var poolsService: (any HydraAavePoolsServiceProtocol)?
    private var discoveredPairs: [HydraAave.TradePair]?

    init(
        account: ChainAccountResponse,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        notificationsRegistrar: AssetsExchangeStateRegistring?,
        apiFactory: HydraAaveTradeExecutorFactoryProtocol,
        reservesDiscoveryFactory: HydraAaveReservesDiscoveryFactoryProtocol,
        discoveryTimeLimit: TimeInterval = HydraAaveFlowState.defaultDiscoveryTimeLimit,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue = .global(),
        logger: LoggerProtocol = Logger.shared
    ) {
        self.account = account
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.notificationsRegistrar = notificationsRegistrar
        self.apiFactory = apiFactory
        self.reservesDiscoveryFactory = reservesDiscoveryFactory
        self.discoveryTimeLimit = discoveryTimeLimit
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue
        self.logger = logger
    }

    convenience init(
        account: ChainAccountResponse,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        notificationsRegistrar: AssetsExchangeStateRegistring?,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue = .global(),
        logger: LoggerProtocol = Logger.shared
    ) {
        self.init(
            account: account,
            connection: connection,
            runtimeProvider: runtimeProvider,
            notificationsRegistrar: notificationsRegistrar,
            apiFactory: HydraAaveTradeExecutorFactory(
                connection: connection,
                runtimeProvider: runtimeProvider,
                operationQueue: operationQueue
            ),
            reservesDiscoveryFactory: HydraAaveReservesDiscoveryFactory(
                connection: connection,
                runtimeProvider: runtimeProvider,
                operationQueue: operationQueue
            ),
            operationQueue: operationQueue,
            workingQueue: workingQueue,
            logger: logger
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
            pairs: discoveredPairs ?? [],
            operationQueue: operationQueue,
            workingQueue: workingQueue,
            logger: logger
        )

        poolsService = service

        pollingState.setup()
        service.setup()

        return service
    }

    func createDiscoveryWrapper() -> CompoundOperationWrapper<[HydraAave.TradePair]> {
        let aggregateWrapper = apiFactory.createAaveTradePairs()

        let fallbackWrapper: CompoundOperationWrapper<[HydraAave.TradePair]>
        fallbackWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            if
                let pairs = try? aggregateWrapper.targetOperation.extractNoCancellableResultData(),
                !pairs.isEmpty {
                return .createWithResult(pairs)
            }

            return self.reservesDiscoveryFactory.createPairsWrapper()
        }

        fallbackWrapper.addDependency(wrapper: aggregateWrapper)

        return fallbackWrapper.insertingHead(operations: aggregateWrapper.allOperations)
    }
}

extension HydraAaveFlowState {
    func createPairsWrapper() -> CompoundOperationWrapper<[HydraAave.TradePair]> {
        mutex.lock()
        let cachedPairs = discoveredPairs
        mutex.unlock()

        if let cachedPairs {
            return .createWithResult(cachedPairs)
        }

        let discoveryLongrun = TimeLimitedLongrun(
            timeLimit: discoveryTimeLimit,
            operationQueue: operationQueue
        ) {
            self.createDiscoveryWrapper()
        }

        let discoveryOperation = LongrunOperation(longrun: AnyLongrun(longrun: discoveryLongrun))

        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()
        discoveryOperation.addDependency(codingFactoryOperation)

        let storingOperation = ClosureOperation<[HydraAave.TradePair]> {
            let pairs = try discoveryOperation.extractNoCancellableResultData()

            self.mutex.lock()
            if self.discoveredPairs == nil {
                self.discoveredPairs = pairs
            }
            let result = self.discoveredPairs ?? pairs
            self.mutex.unlock()

            return result
        }

        storingOperation.addDependency(discoveryOperation)

        return CompoundOperationWrapper(
            targetOperation: storingOperation,
            dependencies: [codingFactoryOperation, discoveryOperation]
        )
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
