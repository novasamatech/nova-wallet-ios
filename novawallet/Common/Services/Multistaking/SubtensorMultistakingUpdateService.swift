import Foundation
import SubstrateSdk
import Operation_iOS

final class SubtensorMultistakingUpdateService: ObservableSyncService {
    struct PositionKey: Hashable {
        let hotkey: AccountId
        let netuid: UInt16
    }

    let accountId: AccountId
    let walletId: MetaAccountModel.Id
    let chainAsset: ChainAsset
    let stakingType: StakingType
    let connection: JSONRPCEngine
    let runtimeService: RuntimeCodingServiceProtocol
    let dashboardRepository: AnyDataProviderRepository<Multistaking.DashboardItemSubtensorPart>
    let stakeStateFetchFactory: SubtensorStakeStateFetchFactoryProtocol
    let cacheRepository: AnyDataProviderRepository<ChainStorageItem>
    let workingQueue: DispatchQueue
    let operationQueue: OperationQueue

    private var hotkeysSubscription: CallbackStorageSubscription<[BytesCodable]>?
    private var alphaTriggerSubscription: CallbackBatchStorageSubscription<BatchStorageSubscriptionRawResult>?
    private var subscribedPositionKeys: Set<PositionKey>?

    private var fetchCallStore = CancellableCallStore()
    private var saveCallStore = CancellableCallStore()

    init(
        walletId: MetaAccountModel.Id,
        accountId: AccountId,
        chainAsset: ChainAsset,
        stakingType: StakingType,
        dashboardRepository: AnyDataProviderRepository<Multistaking.DashboardItemSubtensorPart>,
        stakeStateFetchFactory: SubtensorStakeStateFetchFactoryProtocol,
        cacheRepository: AnyDataProviderRepository<ChainStorageItem>,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue,
        logger: LoggerProtocol
    ) {
        self.walletId = walletId
        self.accountId = accountId
        self.chainAsset = chainAsset
        self.stakingType = stakingType
        self.dashboardRepository = dashboardRepository
        self.stakeStateFetchFactory = stakeStateFetchFactory
        self.cacheRepository = cacheRepository
        self.connection = connection
        self.runtimeService = runtimeService
        self.workingQueue = workingQueue
        self.operationQueue = operationQueue

        super.init(logger: logger)
    }

    override func performSyncUp() {
        clearSubscriptions()
        fetchCallStore.cancel()

        makeHotkeysSubscription(for: accountId, chainId: chainAsset.chain.chainId)
    }

    override func stopSyncUp() {
        fetchCallStore.cancel()
        clearSubscriptions()
    }

    private func clearSubscriptions() {
        hotkeysSubscription = nil

        alphaTriggerSubscription?.unsubscribe()
        alphaTriggerSubscription = nil
        subscribedPositionKeys = nil
    }

    private func makeHotkeysSubscription(for accountId: AccountId, chainId: ChainModel.Id) {
        do {
            let localKey = try LocalStorageKeyFactory().createFromStoragePath(
                SubtensorStakingPallet.stakingHotkeysPath,
                accountId: accountId,
                chainId: chainId
            )

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
                repository: cacheRepository,
                operationQueue: operationQueue,
                callbackQueue: workingQueue
            ) { [weak self] result in
                self?.mutex.lock()

                self?.handleHotkeys(result: result)

                self?.mutex.unlock()
            }
        } catch {
            logger.error("Subscription error: \(error)")

            completeImmediate(error)
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
        logger.debug("Persisting state: \(state)")

        let stakingOption = Multistaking.OptionWithWallet(
            walletId: walletId,
            option: .init(chainAssetId: chainAsset.chainAssetId, type: stakingType)
        )

        let dashboardItem = Multistaking.DashboardItemSubtensorPart(
            stakingOption: stakingOption,
            state: state
        )

        let saveOperation = dashboardRepository.saveOperation({
            [dashboardItem]
        }, {
            []
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
