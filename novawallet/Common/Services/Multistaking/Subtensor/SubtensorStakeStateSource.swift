import Foundation
import SubstrateSdk
import Operation_iOS

protocol SubtensorStakeStateHandler: AnyObject {
    func handleStakeStateFetching()
    func handleStakeState(_ state: Multistaking.SubtensorState)
    func handleStakeStateFailure(_ error: Error)
}

final class SubtensorStakeStateSource {
    let accountId: AccountId
    let chainAssetId: ChainAssetId
    let stakeStateFetchOperationFactory: SubtensorStakeStateFetchOperationFactoryProtocol
    let runtimeConnectionStore: RuntimeConnectionStoring
    let eventCenter: EventCenterProtocol
    let operationQueue: OperationQueue
    let workingQueue: DispatchQueue
    let logger: LoggerProtocol

    private let mutex = NSLock()
    private var handlers: [WeakWrapper] = []
    private var lastState: Multistaking.SubtensorState?
    private var connection: JSONRPCEngine?
    private var runtimeService: RuntimeCodingServiceProtocol?
    private var hotkeysSubscription: CallbackStorageSubscription<[BytesCodable]>?
    private var alphaTriggerSubscription: CallbackBatchRawStorageSubscription?
    private var subscribedPositionKeys: Set<SubtensorHotkeySubnet>?
    private var isAlphaTriggerPrimed = false
    private var fetchTriggerBlockHash: Data?
    private var isRefetchPending = false
    private var isSyncingRequested = false
    private let fetchCallStore = CancellableCallStore()

    init(
        accountId: AccountId,
        chainAssetId: ChainAssetId,
        stakeStateFetchOperationFactory: SubtensorStakeStateFetchOperationFactoryProtocol,
        runtimeConnectionStore: RuntimeConnectionStoring,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue,
        logger: LoggerProtocol
    ) {
        self.accountId = accountId
        self.chainAssetId = chainAssetId
        self.stakeStateFetchOperationFactory = stakeStateFetchOperationFactory
        self.runtimeConnectionStore = runtimeConnectionStore
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue
        self.logger = logger
    }

    deinit {
        fetchCallStore.cancel()
        alphaTriggerSubscription?.unsubscribe()
    }

    func add(handler: SubtensorStakeStateHandler) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        handlers.clearEmptyItems()

        if !handlers.contains(where: { $0.target === handler }) {
            handlers.append(WeakWrapper(target: handler))

            if let lastState {
                workingQueue.async {
                    handler.handleStakeState(lastState)
                }

                return
            }
        }

        requestFetch()
    }

    func remove(handler: SubtensorStakeStateHandler) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        handlers = handlers.filter { $0.target != nil && $0.target !== handler }

        if handlers.isEmpty {
            unsubscribe()
        }
    }

    func refresh() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        handlers.clearEmptyItems()

        guard !handlers.isEmpty else {
            return
        }

        requestFetch()
    }
}

private extension SubtensorStakeStateSource {
    func requestFetch() {
        isSyncingRequested = true

        if hotkeysSubscription == nil {
            subscribe()
        } else {
            trigger(at: nil)
        }
    }

    func subscribe() {
        let connection: JSONRPCEngine
        let runtimeService: RuntimeCodingServiceProtocol

        do {
            connection = try runtimeConnectionStore.getConnection()
            runtimeService = try runtimeConnectionStore.getRuntimeProvider()
        } catch {
            logger.error("Subscription error: \(error)")

            notifyHandlers { $0.handleStakeStateFailure(error) }
            return
        }

        self.connection = connection
        self.runtimeService = runtimeService

        let accountId = accountId

        let request = MapSubscriptionRequest(
            storagePath: SubtensorPallet.stakingHotkeysPath,
            localKey: ""
        ) {
            BytesCodable(wrappedValue: accountId)
        }

        hotkeysSubscription = CallbackStorageSubscription(
            request: request,
            connection: connection,
            runtimeService: runtimeService,
            repository: nil,
            operationQueue: operationQueue,
            callbackWithBlockQueue: workingQueue
        ) { [weak self] result in
            self?.handleHotkeysChange(result.map(\.blockHash))
        }

        eventCenter.add(observer: self, dispatchIn: workingQueue)
    }

    func unsubscribe() {
        fetchCallStore.cancel()
        fetchTriggerBlockHash = nil
        isRefetchPending = false
        isSyncingRequested = false

        hotkeysSubscription = nil
        connection = nil
        runtimeService = nil

        alphaTriggerSubscription?.unsubscribe()
        alphaTriggerSubscription = nil
        subscribedPositionKeys = nil

        lastState = nil

        eventCenter.remove(observer: self)
    }

    func trigger(at blockHash: Data?) {
        guard fetchCallStore.hasCall else {
            fetch(triggeredAt: blockHash)
            return
        }

        if blockHash == nil || blockHash != fetchTriggerBlockHash {
            isRefetchPending = true
        }
    }

    func fetch(triggeredAt blockHash: Data?) {
        fetchTriggerBlockHash = blockHash
        let isSignalled = isSyncingRequested
        isSyncingRequested = false

        executeCancellable(
            wrapper: stakeStateFetchOperationFactory.createStateWrapper(for: accountId),
            inOperationQueue: operationQueue,
            backingCallIn: fetchCallStore,
            runningCallbackIn: workingQueue,
            mutex: mutex
        ) { [weak self] result in
            self?.handle(fetchResult: result)
        }

        if isSignalled {
            notifyHandlers { $0.handleStakeStateFetching() }
        }
    }

    func handle(fetchResult: Result<Multistaking.SubtensorState, Error>) {
        switch fetchResult {
        case let .success(fetchedState):
            let state = fetchedState.byKeepingRootRedeemable(of: lastState)
            lastState = state

            updateAlphaTriggerSubscription(for: state)

            notifyHandlers { $0.handleStakeState(state) }
        case let .failure(error):
            logger.error("State fetch error: \(error)")

            notifyHandlers { $0.handleStakeStateFailure(error) }
        }

        guard isRefetchPending else {
            return
        }

        isRefetchPending = false

        fetch(triggeredAt: nil)
    }

    func handleHotkeysChange(_ result: Result<Data?, Error>) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard hotkeysSubscription != nil else {
            return
        }

        apply(trigger: result)
    }

    func handleAlphaChange(_ result: Result<Data?, Error>) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard alphaTriggerSubscription != nil else {
            return
        }

        if case .success = result, !isAlphaTriggerPrimed {
            isAlphaTriggerPrimed = true
            return
        }

        apply(trigger: result)
    }

    func apply(trigger result: Result<Data?, Error>) {
        switch result {
        case let .success(blockHash):
            trigger(at: blockHash)
        case let .failure(error):
            logger.error("Subscription error: \(error)")

            unsubscribe()

            notifyHandlers { $0.handleStakeStateFailure(error) }
        }
    }

    func notifyHandlers(_ closure: @escaping (SubtensorStakeStateHandler) -> Void) {
        let targets = handlers.compactMap { $0.target as? SubtensorStakeStateHandler }

        workingQueue.async {
            targets.forEach(closure)
        }
    }

    func updateAlphaTriggerSubscription(for state: Multistaking.SubtensorState) {
        let newKeys = Set(
            state.positions.map { SubtensorHotkeySubnet(hotkey: $0.hotkey, netuid: $0.netuid) } +
                state.rootClaimPreviews.filter { $0.redeemable > 0 }.map {
                    SubtensorHotkeySubnet(hotkey: $0.hotkey, netuid: SubtensorPallet.rootNetuid)
                }
        )

        guard newKeys != subscribedPositionKeys else {
            return
        }

        subscribedPositionKeys = newKeys

        alphaTriggerSubscription?.unsubscribe()
        alphaTriggerSubscription = nil
        isAlphaTriggerPrimed = false

        guard !newKeys.isEmpty, let connection, let runtimeService else {
            return
        }

        let requests = newKeys.map { positionKey in
            BatchStorageSubscriptionRequest(
                innerRequest: DoubleMapSubscriptionRequest(
                    storagePath: SubtensorPallet.totalHotkeyAlphaPath,
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
            self?.handleAlphaChange(result.map { $0.blockHashJson.stringValue.flatMap { try? Data(hexString: $0) } })
        }

        alphaTriggerSubscription?.subscribe()
    }
}

extension SubtensorStakeStateSource: EventVisitorProtocol {
    func processSubtensorStakeChanged(event: SubtensorStakeChanged) {
        guard event.accountId == accountId, event.chainAssetId == chainAssetId else {
            return
        }

        refresh()
    }
}
