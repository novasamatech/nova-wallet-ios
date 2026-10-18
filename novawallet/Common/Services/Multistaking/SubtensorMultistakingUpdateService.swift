import Foundation
import SubstrateSdk
import Operation_iOS

final class SubtensorMultistakingUpdateService: ObservableSyncService {
    let walletId: MetaAccountModel.Id
    let chainAsset: ChainAsset
    let stakingType: StakingType
    let dashboardRepository: AnyDataProviderRepository<Multistaking.DashboardItemSubtensorPart>
    let stakeStateSource: SubtensorStakeStateSource
    let maxApyProvider: SubtensorMaxApyProviderProtocol
    let rootYieldService: SubtensorYieldServiceProtocol
    let cataloguePricing: SubtensorCataloguePricingTracker
    let workingQueue: DispatchQueue
    let operationQueue: OperationQueue

    private var maxApyUpdate: Multistaking.DashboardItemSubtensorPart.MaxApyUpdate = .keep
    private var rootYields: SubtensorAlphaYields?
    private var isSyncCompletionDeferred = false

    private lazy var stakeStateSubscription = SubtensorStakeStateSubscription(
        source: stakeStateSource,
        mutex: mutex,
        operationQueue: operationQueue,
        workingQueue: workingQueue,
        onSyncing: { [weak self] in self?.markSyncingImmediate() },
        onState: { [weak self] in self?.handle(state: $0) },
        onFailure: { [weak self] in self?.completeImmediate($0) }
    )

    private var lastState: Multistaking.SubtensorStakingState? {
        stakeStateSubscription.lastState
    }

    private var maxApyCallStore = CancellableCallStore()
    private var rootYieldsCallStore = CancellableCallStore()

    init(
        walletId: MetaAccountModel.Id,
        chainAsset: ChainAsset,
        stakingType: StakingType,
        dashboardRepository: AnyDataProviderRepository<Multistaking.DashboardItemSubtensorPart>,
        stakeStateSource: SubtensorStakeStateSource,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue,
        logger: LoggerProtocol,
        maxApyProvider: SubtensorMaxApyProviderProtocol,
        rootYieldService: SubtensorYieldServiceProtocol,
        cataloguePricing: SubtensorCataloguePricingTracker
    ) {
        self.walletId = walletId
        self.chainAsset = chainAsset
        self.stakingType = stakingType
        self.dashboardRepository = dashboardRepository
        self.stakeStateSource = stakeStateSource
        self.maxApyProvider = maxApyProvider
        self.rootYieldService = rootYieldService
        self.cataloguePricing = cataloguePricing
        self.workingQueue = workingQueue
        self.operationQueue = operationQueue

        super.init(logger: logger)
    }

    override func performSyncUp() {
        seedRootYields()
        cataloguePricing.seed()

        stakeStateSubscription.subscribe()

        performMaxApyFetch()
    }

    override func stopSyncUp() {
        isSyncCompletionDeferred = false
        maxApyCallStore.cancel()
        rootYieldsCallStore.cancel()
        cataloguePricing.cancel()
        stakeStateSubscription.unsubscribe()
    }

    // throttle() skips stopSyncUp() when a fetch already completed, so the storage
    // subscriptions must be released here as well
    override func deactivate() {
        rootYields = nil
        cataloguePricing.reset()

        stopSyncUp()
    }

    private func handle(state: Multistaking.SubtensorStakingState) {
        persistState(state)
        performMaxApyFetch()
        performRootYieldsFetch()
        performCataloguePricingRefresh()
    }

    private func performMaxApyFetch() {
        guard !maxApyCallStore.hasCall else {
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
                self?.updateMaxApy(.replace(maxApy.values.max()))
            case let .failure(error):
                self?.logger.warning("Max APY fetch error: \(error)")
                self?.completeDeferredSync()
            }
        }
    }

    private func completeSync(_ error: Error?, for state: Multistaking.SubtensorStakingState) {
        isSyncCompletionDeferred = error == nil && !state.hasActiveStaking && maxApyUpdate == .keep &&
            maxApyCallStore.hasCall

        guard !isSyncCompletionDeferred else {
            return
        }

        completeImmediate(error)
    }

    private func completeDeferredSync() {
        guard isSyncCompletionDeferred else {
            return
        }

        isSyncCompletionDeferred = false

        if !stakeStateSubscription.isFetching {
            completeImmediate(nil)
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
            rootYields == nil,
            case let .fresh(yields) = rootYieldService.cachedAlphaYields(for: SubtensorStakingPallet.rootNetuid) else {
            return
        }

        rootYields = yields
    }

    private func performRootYieldsFetch() {
        guard !rootYieldsCallStore.hasCall, lastState?.rootStakeInRao != nil else {
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
        cataloguePricing.refresh(
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

        let valuation = cataloguePricing.valuation(of: state)

        let dashboardItem = Multistaking.DashboardItemSubtensorPart(
            stakingOption: stakingOption,
            state: state,
            stake: valuation.stake,
            maxApy: maxApyUpdate,
            rootRate: SubtensorRootRateCalculator.stakeWeightedRate(
                of: state.positions.filter { $0.netuid == SubtensorStakingPallet.rootNetuid },
                in: rootYields
            ),
            isFullyPriced: valuation.isFullyPriced
        )

        let saveWrapper = CompoundOperationWrapper(
            targetOperation: dashboardRepository.saveOperation({ [dashboardItem] }, { [] })
        )

        stakeStateSubscription.save(saveWrapper) { [weak self] in
            self?.completeSync($0, for: state)
        }
    }
}

extension SubtensorMultistakingUpdateService: MultistakingOnchainSyncServiceProtocol {
    func refreshOffchain() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard isActive else {
            return
        }

        stakeStateSubscription.refresh()
    }
}
