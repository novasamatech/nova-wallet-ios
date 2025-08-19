import Foundation
import SubstrateSdk
import Operation_iOS

final class HydraEvmBalanceSyncer: ObservableSyncService {
    typealias TState = [HydraAccountAsset: HydraBalance]

    let accountAssets: Set<HydraAccountAsset>
    let runtimeConnectionStore: RuntimeConnectionStoring
    let operationQueue: OperationQueue
    let workQueue: DispatchQueue

    private var state: [HydraAccountAsset: HydraBalance]?
    private var pollingState: ChainPollingStateStore?
    private let apiFactory: HydrationApiOperationFactoryProtocol
    private let callStore = CancellableCallStore()

    init(
        accountAssets: Set<HydraAccountAsset>,
        runtimeProvider: RuntimeProviderProtocol,
        connection: JSONRPCEngine,
        operationQueue: OperationQueue,
        workQueue: DispatchQueue,
        logger: LoggerProtocol
    ) {
        self.accountAssets = accountAssets

        runtimeConnectionStore = StaticRuntimeConnectionStore(
            connection: connection,
            runtimeProvider: runtimeProvider
        )

        self.operationQueue = operationQueue
        self.workQueue = workQueue

        apiFactory = HydrationApiOperationFactory(
            runtimeConnectionStore: runtimeConnectionStore,
            operationQueue: operationQueue
        )

        super.init(logger: logger)
    }

    override func performSyncUp() {
        guard pollingState == nil else {
            // in case of retry just wait the next block
            completeImmediate(nil)
            return
        }

        pollingState = ChainPollingStateStore(
            runtimeConnectionStore: runtimeConnectionStore,
            operationQueue: operationQueue,
            repository: nil,
            workQueue: workQueue,
            logger: logger
        )

        pollingState?.add(
            observer: self,
            sendStateOnSubscription: true,
            queue: workQueue
        ) { [weak self] _, newState in
            guard let self, let blockHash = newState?.blockHash else {
                return
            }

            mutex.lock()

            defer {
                mutex.unlock()
            }

            loadBalances(for: Array(accountAssets), blockHash: blockHash)
        }
    }

    override func stopSyncUp() {
        pollingState?.throttle()
        pollingState = nil

        callStore.cancel()
    }
}

private extension HydraEvmBalanceSyncer {
    func loadBalances(for accountAssets: [HydraAccountAsset], blockHash: BlockHashData) {
        callStore.cancel()

        let fetchRequestWrappers: [CompoundOperationWrapper<HydrationApi.CurrencyData>]
        fetchRequestWrappers = accountAssets.map { accountAsset in
            apiFactory.createCurrencyBalanceWrapper(
                for: { accountAsset.assetId },
                accountId: accountAsset.accountId,
                blockHash: blockHash.toHex(includePrefix: true)
            )
        }

        let mappingOperation = ClosureOperation<[HydraAccountAsset: HydraBalance]> {
            let responses: [HydrationApi.CurrencyData] = try fetchRequestWrappers.map {
                try $0.targetOperation.extractNoCancellableResultData()
            }

            return zip(accountAssets, responses).reduce(
                into: [HydraAccountAsset: HydraBalance]()
            ) { accum, pair in
                accum[pair.0] = HydraBalance(currencyData: pair.1)
            }
        }

        fetchRequestWrappers.forEach { mappingOperation.addDependency($0.targetOperation) }

        let dependencies = fetchRequestWrappers.flatMap(\.allOperations)

        let wrapper = CompoundOperationWrapper(
            targetOperation: mappingOperation,
            dependencies: dependencies
        )

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: workQueue,
            mutex: mutex
        ) { [weak self] newBalancesResult in
            guard let self else {
                return
            }

            switch newBalancesResult {
            case let .success(newBalances):
                updateBalances(for: newBalances)
            case let .failure(error):
                completeImmediate(error)
            }
        }
    }

    func updateBalances(for newBalances: [HydraAccountAsset: HydraBalance]) {
        guard state != newBalances else {
            completeImmediate(nil)
            return
        }

        logger.debug("New balances: \(newBalances)")

        state = newBalances

        if !isSyncing {
            isSyncing = true
        }

        completeImmediate(nil)
    }
}

extension HydraEvmBalanceSyncer: ObservableSubscriptionSyncServiceProtocol {
    func getState() -> TState? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return state
    }
}
