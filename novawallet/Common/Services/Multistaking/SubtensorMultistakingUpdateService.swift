import Foundation
import SubstrateSdk
import Operation_iOS

final class SubtensorMultistakingUpdateService: ObservableSyncService {
    let accountId: AccountId
    let walletId: MetaAccountModel.Id
    let chainAsset: ChainAsset
    let stakingType: StakingType
    let connection: JSONRPCEngine
    let runtimeService: RuntimeCodingServiceProtocol
    let dashboardRepository: AnyDataProviderRepository<Multistaking.DashboardItemSubtensorPart>
    let stakeStateFetchFactory: SubtensorStakeStateFetchFactoryProtocol
    let cacheRepository: AnyDataProviderRepository<ChainStorageItem>
    let maxApyProvider: SubtensorMaxApyProviderProtocol?
    let rootYieldService: SubtensorYieldServiceProtocol?
    let cataloguePricing: SubtensorCataloguePricingTracker?
    let eventCenter: EventCenterProtocol
    let workingQueue: DispatchQueue
    let operationQueue: OperationQueue

    private var maxApyUpdate: Multistaking.DashboardItemSubtensorPart.MaxApyUpdate = .keep
    private var rootYields: SubtensorAlphaYields?
    private var isMaxApyResolved = false

    private lazy var stakeStateSubscription = SubtensorStakeStateSubscription(
        accountId: accountId,
        stakeStateFetchFactory: stakeStateFetchFactory,
        connection: connection,
        runtimeService: runtimeService,
        hotkeysCache: (cacheRepository, chainAsset.chain.chainId),
        mutex: mutex,
        operationQueue: operationQueue,
        workingQueue: workingQueue,
        logger: logger,
        onSyncing: { [weak self] in self?.markSyncingImmediate() },
        onState: { [weak self] in self?.handle(state: $0) },
        onFailure: { [weak self] in self?.completeImmediate($0) }
    )

    private var lastState: Multistaking.SubtensorStakingState? {
        stakeStateSubscription.lastState
    }

    private var maxApyCallStore = CancellableCallStore()
    private var rootYieldsCallStore = CancellableCallStore()
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
        logger: LoggerProtocol,
        maxApyProvider: SubtensorMaxApyProviderProtocol? = nil,
        rootYieldService: SubtensorYieldServiceProtocol? = nil,
        cataloguePricing: SubtensorCataloguePricingTracker? = nil,
        eventCenter: EventCenterProtocol = EventCenter.shared
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
        self.maxApyProvider = maxApyProvider
        self.rootYieldService = rootYieldService
        self.cataloguePricing = cataloguePricing
        self.eventCenter = eventCenter
        self.workingQueue = workingQueue
        self.operationQueue = operationQueue

        super.init(logger: logger)
    }

    override func performSyncUp() {
        isMaxApyResolved = false

        seedRootYields()
        cataloguePricing?.seed()

        eventCenter.add(observer: self, dispatchIn: workingQueue)

        stakeStateSubscription.subscribe()
    }

    override func stopSyncUp() {
        maxApyCallStore.cancel()
        rootYieldsCallStore.cancel()
        cataloguePricing?.cancel()
        stakeStateSubscription.unsubscribe()
    }

    // throttle() skips stopSyncUp() when a fetch already completed, so the storage
    // subscriptions must be released here as well
    override func deactivate() {
        eventCenter.remove(observer: self)

        maxApyCallStore.cancel()
        rootYieldsCallStore.cancel()
        cataloguePricing?.cancel()
        stakeStateSubscription.unsubscribe()
    }

    func refreshCataloguePricing() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard isActive else {
            return
        }

        performCataloguePricingRefresh()
    }

    private func handle(state: Multistaking.SubtensorStakingState) {
        persistState(state)
        performMaxApyFetch()
        performRootYieldsFetch()
        performCataloguePricingRefresh()
    }

    private func performMaxApyFetch() {
        guard let maxApyProvider, !isMaxApyResolved, !maxApyCallStore.hasCall else {
            return
        }

        executeCancellable(
            wrapper: maxApyProvider.createMaxApyWrapper(),
            inOperationQueue: operationQueue,
            backingCallIn: maxApyCallStore,
            runningCallbackIn: workingQueue,
            mutex: mutex
        ) { [weak self] result in
            switch result {
            case let .success(maxApy):
                self?.isMaxApyResolved = true
                self?.updateMaxApy(.replace(maxApy))
            case let .failure(error):
                self?.logger.warning("Max APY fetch error: \(error)")
            }
        }
    }

    private func updateMaxApy(_ newUpdate: Multistaking.DashboardItemSubtensorPart.MaxApyUpdate) {
        guard newUpdate != maxApyUpdate else {
            return
        }

        maxApyUpdate = newUpdate

        persistLastStateIfIdle()
    }

    private func seedRootYields() {
        guard
            let rootYieldService,
            case let .fresh(yields) = rootYieldService.cachedAlphaYields(
                for: SubtensorStakingPallet.rootNetuid
            ) else {
            rootYields = nil
            return
        }

        rootYields = yields
    }

    private func performRootYieldsFetch() {
        guard let rootYieldService, !rootYieldsCallStore.hasCall, lastState?.rootStakeInRao != nil else {
            return
        }

        executeCancellable(
            wrapper: rootYieldService.createAlphaYieldsWrapper(for: SubtensorStakingPallet.rootNetuid),
            inOperationQueue: operationQueue,
            backingCallIn: rootYieldsCallStore,
            runningCallbackIn: workingQueue,
            mutex: mutex
        ) { [weak self] result in
            switch result {
            case let .success(yields):
                self?.updateRootYields(yields)
            case let .failure(error):
                self?.logger.warning("Root yields fetch error: \(error)")
            }
        }
    }

    private func updateRootYields(_ newRootYields: SubtensorAlphaYields) {
        guard newRootYields != rootYields else {
            return
        }

        rootYields = newRootYields

        persistLastStateIfIdle()
    }

    private func persistLastStateIfIdle() {
        guard let lastState, !stakeStateSubscription.isFetching else {
            return
        }

        markSyncingImmediate()

        persistState(lastState)
    }

    private func performCataloguePricingRefresh() {
        cataloguePricing?.refresh(
            latestState: { [weak self] in self?.lastState },
            runningCallbackIn: workingQueue,
            mutex: mutex,
            onUpdate: { [weak self] didChange in
                if didChange {
                    self?.persistLastStateIfIdle()
                }
            }
        )
    }

    private func persistState(_ state: Multistaking.SubtensorStakingState) {
        logger.debug("Persisting state: \(state)")

        let stakingOption = Multistaking.OptionWithWallet(
            walletId: walletId,
            option: .init(chainAssetId: chainAsset.chainAssetId, type: stakingType)
        )

        let valuation = cataloguePricing?.valuation(of: state)

        let dashboardItem = Multistaking.DashboardItemSubtensorPart(
            stakingOption: stakingOption,
            state: state,
            stake: valuation?.stake ?? state.rootStakeInRao ?? .zero,
            maxApy: maxApyUpdate,
            rootRate: SubtensorAlphaApyFormatter.stakeWeightedRate(
                of: state.positions.filter { $0.netuid == SubtensorStakingPallet.rootNetuid },
                in: rootYields
            ),
            isFullyPriced: valuation?.isFullyPriced
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
                self?.completeImmediate(state.rootRedeemableError)
            case let .failure(error):
                self?.completeImmediate(error)
            }
        }
    }
}

extension SubtensorMultistakingUpdateService: EventVisitorProtocol {
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

        stakeStateSubscription.refresh()
    }
}
