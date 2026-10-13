import Foundation
import SubstrateSdk
import Operation_iOS

final class SubtensorStakedBalanceUpdatingService: BaseSyncService {
    struct PositionKey: Hashable {
        let hotkey: AccountId
        let netuid: UInt16
    }

    let accountId: AccountId
    let chainAsset: ChainAsset
    let connection: JSONRPCEngine
    let runtimeService: RuntimeCodingServiceProtocol
    let repository: AnyDataProviderRepository<SubtensorStakedBalance>
    let stakeStateFetchFactory: SubtensorStakeStateFetchFactoryProtocol
    let cataloguePricing: SubtensorCataloguePricingTracker
    let eventCenter: EventCenterProtocol
    let workingQueue: DispatchQueue
    let operationQueue: OperationQueue

    private var hotkeysSubscription: CallbackStorageSubscription<[BytesCodable]>?
    private var alphaTriggerSubscription: CallbackBatchRawStorageSubscription?
    private var subscribedPositionKeys: Set<PositionKey>?
    private var lastState: Multistaking.SubtensorStakingState?

    private var fetchCallStore = CancellableCallStore()
    private var saveCallStore = CancellableCallStore()

    init(
        accountId: AccountId,
        chainAsset: ChainAsset,
        repository: AnyDataProviderRepository<SubtensorStakedBalance>,
        stakeStateFetchFactory: SubtensorStakeStateFetchFactoryProtocol,
        cataloguePricing: SubtensorCataloguePricingTracker,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue,
        logger: LoggerProtocol,
        eventCenter: EventCenterProtocol = EventCenter.shared
    ) {
        self.accountId = accountId
        self.chainAsset = chainAsset
        self.repository = repository
        self.stakeStateFetchFactory = stakeStateFetchFactory
        self.cataloguePricing = cataloguePricing
        self.connection = connection
        self.runtimeService = runtimeService
        self.eventCenter = eventCenter
        self.workingQueue = workingQueue
        self.operationQueue = operationQueue

        super.init(logger: logger)
    }

    override func performSyncUp() {
        clearSubscriptions()
        fetchCallStore.cancel()

        eventCenter.add(observer: self, dispatchIn: workingQueue)

        makeHotkeysSubscription(for: accountId)
    }

    override func stopSyncUp() {
        fetchCallStore.cancel()
        cataloguePricing.cancel()
        clearSubscriptions()
    }

    // throttle() skips stopSyncUp() when a fetch already completed, so the storage
    // subscriptions must be released here as well
    override func deactivate() {
        eventCenter.remove(observer: self)

        fetchCallStore.cancel()
        cataloguePricing.cancel()
        clearSubscriptions()
    }

    private func clearSubscriptions() {
        hotkeysSubscription = nil

        alphaTriggerSubscription?.unsubscribe()
        alphaTriggerSubscription = nil
        subscribedPositionKeys = nil
    }

    private func makeHotkeysSubscription(for accountId: AccountId) {
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

    private func handleHotkeys(result: Result<[BytesCodable]?, Error>) {
        switch result {
        case .success:
            markSyncingImmediate()

            performStateFetch()
        case let .failure(error):
            completeImmediate(error)
        }
    }

    private func handleAlphaTrigger(result: Result<BatchStorageSubscriptionRawResult, Error>) {
        switch result {
        case .success:
            markSyncingImmediate()

            performStateFetch()
        case let .failure(error):
            completeImmediate(error)
        }
    }

    private func performStateFetch() {
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
                let state = fetchedState.byKeepingRootRedeemable(of: self?.lastState)
                self?.lastState = state
                self?.updateAlphaTriggerSubscription(for: state)
                self?.persistPricedState(state)
            case let .failure(error):
                self?.logger.error("State fetch error: \(error)")

                self?.completeImmediate(error)
            }
        }
    }

    private func updateAlphaTriggerSubscription(for state: Multistaking.SubtensorStakingState) {
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
            self?.mutex.lock()

            self?.handleAlphaTrigger(result: result)

            self?.mutex.unlock()
        }

        alphaTriggerSubscription?.subscribe()
    }

    private func persistPricedState(_ state: Multistaking.SubtensorStakingState) {
        guard state.subnetCount > 0 else {
            persistState(state)
            return
        }

        cataloguePricing.refresh(
            latestState: { [weak self] in self?.lastState },
            runningCallbackIn: workingQueue,
            mutex: mutex,
            onUpdate: { [weak self] _ in
                guard let self, let lastState else {
                    return
                }

                persistState(lastState)
            }
        )
    }

    private func persistState(_ state: Multistaking.SubtensorStakingState) {
        let wrapper = createSaveWrapper(for: state)

        if let pendingOperations = saveCallStore.operatingCall?.allOperations {
            wrapper.addDependency(operations: pendingOperations)
        }

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: saveCallStore,
            runningCallbackIn: workingQueue,
            mutex: mutex
        ) { [weak self] result in
            switch result {
            case .success:
                self?.completeImmediate(state.rootRedeemableError)
            case let .failure(error):
                self?.completeImmediate(error)
            }
        }
    }
}

private extension SubtensorStakedBalanceUpdatingService {
    func createSaveWrapper(for state: Multistaking.SubtensorStakingState) -> CompoundOperationWrapper<Void> {
        let identifier = SubtensorStakedBalance.createIdentifier(from: chainAsset.chainAssetId, accountId: accountId)

        guard state.hasActiveStaking else {
            return CompoundOperationWrapper(targetOperation: repository.saveOperation({ [] }, { [identifier] }))
        }

        let valuation = cataloguePricing.valuation(of: state)

        let item = SubtensorStakedBalance(
            chainAssetId: chainAsset.chainAssetId,
            accountId: accountId,
            amount: valuation.stake,
            isComplete: valuation.isFullyPriced == true
        )

        guard !item.isComplete else {
            return CompoundOperationWrapper(targetOperation: repository.saveOperation({ [item] }, { [] }))
        }

        // a partial total never replaces a complete one; it only fills in or updates an earlier partial
        let fetchOperation = repository.fetchOperation(by: { identifier }, options: .init())

        let saveOperation = repository.saveOperation({
            let stored = try fetchOperation.extractNoCancellableResultData()

            guard stored?.isComplete != true else {
                return []
            }

            return [item]
        }, { [] })

        saveOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(targetOperation: saveOperation, dependencies: [fetchOperation])
    }
}

extension SubtensorStakedBalanceUpdatingService: EventVisitorProtocol {
    func processSubtensorStakingChanged(event: SubtensorStakingChanged) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard
            isActive,
            event.accountId == accountId,
            event.chainAssetId == chainAsset.chainAssetId else {
            return
        }

        markSyncingImmediate()

        performStateFetch()
    }
}
