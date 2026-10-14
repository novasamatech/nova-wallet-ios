import Foundation
import SubstrateSdk
import Operation_iOS

final class SubtensorStakeStateSubscription {
    typealias HotkeysCache = (repository: AnyDataProviderRepository<ChainStorageItem>, chainId: ChainModel.Id)

    private struct PositionKey: Hashable {
        let hotkey: AccountId
        let netuid: UInt16
    }

    let accountId: AccountId
    let stakeStateFetchFactory: SubtensorStakeStateFetchFactoryProtocol
    let connection: JSONRPCEngine
    let runtimeService: RuntimeCodingServiceProtocol
    let hotkeysCache: HotkeysCache?
    let mutex: NSLock
    let operationQueue: OperationQueue
    let workingQueue: DispatchQueue
    let logger: LoggerProtocol
    let onSyncing: () -> Void
    let onState: (Multistaking.SubtensorStakingState) -> Void
    let onFailure: (Error) -> Void

    private(set) var lastState: Multistaking.SubtensorStakingState?

    private var hotkeysSubscription: CallbackStorageSubscription<[BytesCodable]>?
    private var alphaTriggerSubscription: CallbackBatchRawStorageSubscription?
    private var subscribedPositionKeys: Set<PositionKey>?
    private var fetchCallStore = CancellableCallStore()

    var isFetching: Bool {
        fetchCallStore.hasCall
    }

    init(
        accountId: AccountId,
        stakeStateFetchFactory: SubtensorStakeStateFetchFactoryProtocol,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        hotkeysCache: HotkeysCache? = nil,
        mutex: NSLock,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue,
        logger: LoggerProtocol,
        onSyncing: @escaping () -> Void,
        onState: @escaping (Multistaking.SubtensorStakingState) -> Void,
        onFailure: @escaping (Error) -> Void
    ) {
        self.accountId = accountId
        self.stakeStateFetchFactory = stakeStateFetchFactory
        self.connection = connection
        self.runtimeService = runtimeService
        self.hotkeysCache = hotkeysCache
        self.mutex = mutex
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue
        self.logger = logger
        self.onSyncing = onSyncing
        self.onState = onState
        self.onFailure = onFailure
    }

    deinit {
        unsubscribe()
    }

    func subscribe() {
        unsubscribe()

        do {
            let accountId = accountId

            let localKey = try hotkeysCache.map {
                try LocalStorageKeyFactory().createFromStoragePath(
                    SubtensorStakingPallet.stakingHotkeysPath,
                    accountId: accountId,
                    chainId: $0.chainId
                )
            } ?? .empty

            let request = MapSubscriptionRequest(
                storagePath: SubtensorStakingPallet.stakingHotkeysPath,
                localKey: localKey
            ) {
                BytesCodable(wrappedValue: accountId)
            }

            hotkeysSubscription = CallbackStorageSubscription(
                request: request,
                connection: connection,
                runtimeService: runtimeService,
                repository: hotkeysCache?.repository,
                operationQueue: operationQueue,
                callbackQueue: workingQueue
            ) { [weak self] result in
                self?.handleChange(result)
            }
        } catch {
            logger.error("Subscription error: \(error)")

            onFailure(error)
        }
    }

    func unsubscribe() {
        fetchCallStore.cancel()

        hotkeysSubscription = nil

        alphaTriggerSubscription?.unsubscribe()
        alphaTriggerSubscription = nil
        subscribedPositionKeys = nil
    }

    func refresh() {
        onSyncing()

        fetchCallStore.cancel()

        executeCancellable(
            wrapper: stakeStateFetchFactory.createStateWrapper(for: accountId),
            inOperationQueue: operationQueue,
            backingCallIn: fetchCallStore,
            runningCallbackIn: workingQueue,
            mutex: mutex
        ) { [weak self] result in
            switch result {
            case let .success(fetchedState):
                self?.handle(fetchedState: fetchedState)
            case let .failure(error):
                self?.logger.error("State fetch error: \(error)")

                self?.onFailure(error)
            }
        }
    }
}

private extension SubtensorStakeStateSubscription {
    func handleChange<T>(_ result: Result<T, Error>) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        switch result {
        case .success:
            refresh()
        case let .failure(error):
            onFailure(error)
        }
    }

    func handle(fetchedState: Multistaking.SubtensorStakingState) {
        let state = fetchedState.byKeepingRootRedeemable(of: lastState)
        lastState = state

        updateAlphaTriggerSubscription(for: state)

        onState(state)
    }

    func updateAlphaTriggerSubscription(for state: Multistaking.SubtensorStakingState) {
        let newKeys = Set(
            state.positions.map { PositionKey(hotkey: $0.hotkey, netuid: $0.netuid) } +
                state.rootRedeemable.keys.map { PositionKey(hotkey: $0, netuid: SubtensorStakingPallet.rootNetuid) }
        )

        guard newKeys != subscribedPositionKeys else {
            return
        }

        subscribedPositionKeys = newKeys

        alphaTriggerSubscription?.unsubscribe()
        alphaTriggerSubscription = nil

        guard !newKeys.isEmpty else {
            return
        }

        let requests = newKeys.map { positionKey in
            BatchStorageSubscriptionRequest(
                innerRequest: DoubleMapSubscriptionRequest(
                    storagePath: SubtensorStakingPallet.totalHotkeyAlphaPath,
                    localKey: "",
                    keyParamClosure: {
                        (
                            BytesCodable(wrappedValue: positionKey.hotkey),
                            StringScaleMapper(value: positionKey.netuid)
                        )
                    }
                ),
                mappingKey: nil
            )
        }

        alphaTriggerSubscription = CallbackBatchStorageSubscription(
            requests: requests,
            connection: connection,
            runtimeService: runtimeService,
            repository: nil,
            operationQueue: operationQueue,
            callbackQueue: workingQueue
        ) { [weak self] result in
            self?.handleChange(result)
        }

        alphaTriggerSubscription?.subscribe()
    }
}
