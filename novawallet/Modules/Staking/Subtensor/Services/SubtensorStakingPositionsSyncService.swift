import Foundation
import Operation_iOS
import SubstrateSdk

protocol SubtensorPositionsSyncServiceProtocol: ApplicationServiceProtocol {
    func add(
        observer: AnyObject,
        sendStateOnSubscription: Bool,
        queue: DispatchQueue?,
        closure: @escaping Observable<Multistaking.SubtensorStakingState?>.StateChangeClosure
    )

    func remove(observer: AnyObject)

    /// `BaseSyncService` only logs and reschedules on failure, so a parallel observable is the
    /// one way a caller can tell "still loading" from "we could not read the chain" (spec §3.2)
    func add(
        failureObserver: AnyObject,
        sendStateOnSubscription: Bool,
        queue: DispatchQueue?,
        closure: @escaping Observable<Bool>.StateChangeClosure
    )

    func remove(failureObserver: AnyObject)

    func refresh()
}

/// the `TotalHotkeyAlpha` values behind the position resync trigger, keyed by mapping key
struct SubtensorHotkeyAlphaBatch: BatchStorageSubscriptionResult {
    let amounts: [String: Balance]

    init(
        values: [BatchStorageSubscriptionResultValue],
        blockHashJson _: JSON,
        context: [CodingUserInfoKey: Any]?
    ) throws {
        amounts = try values.reduce(into: [String: Balance]()) { accum, item in
            guard let mappingKey = item.mappingKey else {
                return
            }

            // TotalHotkeyAlpha is ValueQuery, so a null read means the hotkey holds no alpha there
            let decoded = try item.value.map(to: StringScaleMapper<Balance>?.self, with: context)

            accum[mappingKey] = decoded?.value ?? 0
        }
    }
}

final class SubtensorStakingPositionsSyncService: BaseSyncService {
    struct PositionKey: Hashable {
        let hotkey: AccountId
        let netuid: UInt16
    }

    let accountId: AccountId
    let connection: JSONRPCEngine
    let runtimeService: RuntimeCodingServiceProtocol
    let stakeStateFetchFactory: SubtensorStakeStateFetchFactoryProtocol
    let workingQueue: DispatchQueue
    let operationQueue: OperationQueue

    private var hotkeysSubscription: CallbackStorageSubscription<[BytesCodable]>?
    private var alphaTriggerSubscription: CallbackBatchStorageSubscription<SubtensorHotkeyAlphaBatch>?
    private var subscribedPositionKeys: Set<PositionKey>?

    private var hotkeyAlphaByPosition: [PositionKey: Balance] = [:]

    private var fetchCallStore = CancellableCallStore()

    private var stateObservable: Observable<Multistaking.SubtensorStakingState?> = .init(state: nil)
    private var failureObservable: Observable<Bool> = .init(state: false)

    init(
        accountId: AccountId,
        stakeStateFetchFactory: SubtensorStakeStateFetchFactoryProtocol,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue,
        logger: LoggerProtocol
    ) {
        self.accountId = accountId
        self.stakeStateFetchFactory = stakeStateFetchFactory
        self.connection = connection
        self.runtimeService = runtimeService
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue

        super.init(logger: logger)
    }

    deinit {
        fetchCallStore.cancel()
        clearSubscriptions()
    }

    override func performSyncUp() {
        clearSubscriptions()
        fetchCallStore.cancel()

        makeHotkeysSubscription(for: accountId)
    }

    override func stopSyncUp() {
        fetchCallStore.cancel()
        clearSubscriptions()
    }

    // throttle() skips stopSyncUp() when a fetch already completed, so the batch
    // subscription must be released here as well
    override func deactivate() {
        fetchCallStore.cancel()
        clearSubscriptions()
    }
}

extension SubtensorStakingPositionsSyncService {
    static func mappingKey(for positionKey: PositionKey) -> String {
        "\(positionKey.hotkey.toHex())-\(positionKey.netuid)"
    }

    /// a storage update carries only the keys that changed, so the map is merged, never replaced,
    /// and a payload key outside the subscribed set is dropped rather than accumulated
    static func merging(
        _ current: [PositionKey: Balance],
        with batch: SubtensorHotkeyAlphaBatch,
        subscribedKeys: Set<PositionKey>
    ) -> [PositionKey: Balance] {
        let keyByMapping = subscribedKeys.reduce(into: [String: PositionKey]()) { accum, key in
            accum[mappingKey(for: key)] = key
        }

        return batch.amounts.reduce(into: current) { accum, item in
            guard let positionKey = keyByMapping[item.key] else {
                return
            }

            accum[positionKey] = item.value
        }
    }

    /// a position that left the subscribed set stops receiving updates, so its denominator goes
    /// rather than being carried forward at its last value
    static func pruning(
        _ current: [PositionKey: Balance],
        to subscribedKeys: Set<PositionKey>
    ) -> [PositionKey: Balance] {
        current.filter { subscribedKeys.contains($0.key) }
    }
}

private extension SubtensorStakingPositionsSyncService {
    func clearSubscriptions() {
        hotkeysSubscription = nil

        alphaTriggerSubscription?.unsubscribe()
        alphaTriggerSubscription = nil
        subscribedPositionKeys = nil
        hotkeyAlphaByPosition = [:]
    }

    func decorate(
        _ state: Multistaking.SubtensorStakingState
    ) -> Multistaking.SubtensorStakingState {
        let positions = state.positions.map { position in
            let key = PositionKey(hotkey: position.hotkey, netuid: position.netuid)

            return position.byReplacing(totalHotkeyAlpha: hotkeyAlphaByPosition[key])
        }

        return state.byReplacing(positions: positions)
    }

    func makeHotkeysSubscription(for accountId: AccountId) {
        let request = MapSubscriptionRequest(
            storagePath: SubtensorStakingPallet.stakingHotkeysPath,
            localKey: .empty
        ) {
            BytesCodable(wrappedValue: accountId)
        }

        hotkeysSubscription = CallbackStorageSubscription(
            request: request,
            connection: connection,
            runtimeService: runtimeService,
            repository: nil,
            operationQueue: operationQueue,
            callbackQueue: workingQueue
        ) { [weak self] result in
            self?.mutex.lock()

            self?.handleHotkeys(result: result)

            self?.mutex.unlock()
        }
    }

    func handleHotkeys(result: Result<[BytesCodable]?, Error>) {
        switch result {
        case .success:
            markSyncingImmediate()

            performStateFetch()
        case let .failure(error):
            markFailed(error)
        }
    }

    func handleAlphaTrigger(result: Result<SubtensorHotkeyAlphaBatch, Error>) {
        switch result {
        case let .success(batch):
            hotkeyAlphaByPosition = Self.merging(
                hotkeyAlphaByPosition,
                with: batch,
                subscribedKeys: subscribedPositionKeys ?? []
            )

            markSyncingImmediate()

            performStateFetch()
        case let .failure(error):
            markFailed(error)
        }
    }

    func markFailed(_ error: Error) {
        failureObservable.state = true

        completeImmediate(error)
    }

    func performStateFetch() {
        fetchCallStore.cancel()

        let wrapper = stakeStateFetchFactory.createStateWrapper(for: accountId)

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: fetchCallStore,
            runningCallbackIn: workingQueue,
            mutex: mutex
        ) { [weak self] result in
            switch result {
            case let .success(fetchedState):
                let state = fetchedState.byKeepingRootRedeemable(of: self?.stateObservable.state)

                self?.updateAlphaTriggerSubscription(for: state)

                self?.failureObservable.state = false

                self?.stateObservable.state = self?.decorate(state)

                self?.completeImmediate(state.rootRedeemableError)
            case let .failure(error):
                self?.logger.error("State fetch error: \(error)")

                self?.markFailed(error)
            }
        }
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

        hotkeyAlphaByPosition = Self.pruning(hotkeyAlphaByPosition, to: newKeys)

        alphaTriggerSubscription?.unsubscribe()
        alphaTriggerSubscription = nil

        guard !newKeys.isEmpty else {
            return
        }

        // the mapping key turns the trigger payload into the per-position TotalHotkeyAlpha values
        // the "≈ X α/day" row needs, at no extra request cost
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
                mappingKey: Self.mappingKey(for: positionKey)
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
            self?.mutex.lock()

            self?.handleAlphaTrigger(result: result)

            self?.mutex.unlock()
        }

        alphaTriggerSubscription?.subscribe()
    }
}

extension SubtensorStakingPositionsSyncService: SubtensorPositionsSyncServiceProtocol {
    func add(
        observer: AnyObject,
        sendStateOnSubscription: Bool,
        queue: DispatchQueue?,
        closure: @escaping Observable<Multistaking.SubtensorStakingState?>.StateChangeClosure
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        stateObservable.addObserver(
            with: observer,
            sendStateOnSubscription: sendStateOnSubscription,
            queue: queue,
            closure: closure
        )
    }

    func remove(observer: AnyObject) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        stateObservable.removeObserver(by: observer)
    }

    func add(
        failureObserver: AnyObject,
        sendStateOnSubscription: Bool,
        queue: DispatchQueue?,
        closure: @escaping Observable<Bool>.StateChangeClosure
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        failureObservable.addObserver(
            with: failureObserver,
            sendStateOnSubscription: sendStateOnSubscription,
            queue: queue,
            closure: closure
        )
    }

    func remove(failureObserver: AnyObject) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        failureObservable.removeObserver(by: failureObserver)
    }

    func refresh() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard isActive else {
            return
        }

        markSyncingImmediate()

        performStateFetch()
    }
}
