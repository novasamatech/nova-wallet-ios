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
    let workingQueue: DispatchQueue
    let operationQueue: OperationQueue

    private var hotkeysSubscription: CallbackStorageSubscription<[BytesCodable]>?
    private var alphaTriggerSubscription: CallbackBatchRawStorageSubscription?
    private var subscribedPositionKeys: Set<PositionKey>?

    private var fetchCallStore = CancellableCallStore()
    private var saveCallStore = CancellableCallStore()

    init(
        accountId: AccountId,
        chainAsset: ChainAsset,
        repository: AnyDataProviderRepository<SubtensorStakedBalance>,
        stakeStateFetchFactory: SubtensorStakeStateFetchFactoryProtocol,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue,
        logger: LoggerProtocol
    ) {
        self.accountId = accountId
        self.chainAsset = chainAsset
        self.repository = repository
        self.stakeStateFetchFactory = stakeStateFetchFactory
        self.connection = connection
        self.runtimeService = runtimeService
        self.workingQueue = workingQueue
        self.operationQueue = operationQueue

        super.init(logger: logger)
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

    // throttle() skips stopSyncUp() when a fetch already completed, so the storage
    // subscriptions must be released here as well
    override func deactivate() {
        fetchCallStore.cancel()
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
            case let .success(state):
                self?.updateAlphaTriggerSubscription(for: state)
                self?.persistState(state)
            case let .failure(error):
                self?.logger.error("State fetch error: \(error)")

                self?.completeImmediate(error)
            }
        }
    }

    // Keys cover only current positions: a stake to a tracked hotkey on a new subnet moves neither
    // StakingHotkeys nor a subscribed key, so external re-drives (polling refresh now, the
    // extrinsic-monitor trigger in the root-flows stage) are required to close that gap
    private func updateAlphaTriggerSubscription(for state: Multistaking.SubtensorStakingState) {
        let newKeys = Set(
            state.positions.map { PositionKey(hotkey: $0.hotkey, netuid: $0.netuid) }
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

    private func persistState(_ state: Multistaking.SubtensorStakingState) {
        let optItem: SubtensorStakedBalance?
        let removeIdentifier: String?

        if state.hasActiveStaking {
            optItem = SubtensorStakedBalance(
                chainAssetId: chainAsset.chainAssetId,
                accountId: accountId,
                amount: state.totalStakeInRao
            )

            removeIdentifier = nil
        } else {
            optItem = nil

            removeIdentifier = SubtensorStakedBalance.createIdentifier(
                from: chainAsset.chainAssetId,
                accountId: accountId
            )
        }

        let saveOperation = repository.saveOperation({
            optItem.map { [$0] } ?? []
        }, {
            removeIdentifier.map { [$0] } ?? []
        })

        let wrapper = CompoundOperationWrapper(targetOperation: saveOperation)

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
                self?.completeImmediate(nil)
            case let .failure(error):
                self?.completeImmediate(error)
            }
        }
    }
}
