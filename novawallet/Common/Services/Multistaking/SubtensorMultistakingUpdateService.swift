import Foundation
import SubstrateSdk
import Operation_iOS

final class SubtensorMultistakingUpdateService: ObservableSyncService {
    let walletId: MetaAccountModel.Id
    let chainAsset: ChainAsset
    let stakingType: StakingType
    let dashboardRepository: AnyDataProviderRepository<Multistaking.DashboardItemSubtensorPart>
    let stakeStateSource: SubtensorStakeStateSource
    let maxApyOperationFactory: SubtensorMaxApyOperationFactoryProtocol
    let yieldOperationFactory: SubtensorYieldOperationFactoryProtocol
    let cataloguePricing: SubtensorCataloguePricingTracker
    let workingQueue: DispatchQueue
    let operationQueue: OperationQueue

    private var maxApyUpdate: Multistaking.DashboardItemSubtensorPart.MaxApyUpdate = .keep
    private var rootYields: SubtensorAlphaYields?
    private var requestedRootHotkeys: Set<AccountId>?
    private var subnetYields: [UInt16: SubtensorAlphaYields] = [:]
    private var requestedSubnetNetuids: Set<UInt16>?
    private var isSyncCompletionDeferred = false

    private lazy var stakeStateSubscription = SubtensorStakeStateSubscription(
        source: stakeStateSource,
        mutex: mutex,
        operationQueue: operationQueue,
        workingQueue: workingQueue,
        onSyncing: { [weak self] in self?.markSyncingImmediate() },
        onState: { [weak self] in self?.handle(state: $0) },
        onFailure: { [weak self] in self?.completeImmediate($0) },
        onUnchangedState: { [weak self] _ in self?.performCataloguePricingRefresh() }
    )

    private var lastState: Multistaking.SubtensorState? {
        stakeStateSubscription.lastState
    }

    private var maxApyCallStore = CancellableCallStore()
    private var rootYieldsCallStore = CancellableCallStore()
    private var subnetYieldsCallStore = CancellableCallStore()

    init(
        walletId: MetaAccountModel.Id,
        chainAsset: ChainAsset,
        stakingType: StakingType,
        dashboardRepository: AnyDataProviderRepository<Multistaking.DashboardItemSubtensorPart>,
        stakeStateSource: SubtensorStakeStateSource,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue,
        logger: LoggerProtocol,
        maxApyOperationFactory: SubtensorMaxApyOperationFactoryProtocol,
        yieldOperationFactory: SubtensorYieldOperationFactoryProtocol,
        cataloguePricing: SubtensorCataloguePricingTracker
    ) {
        self.walletId = walletId
        self.chainAsset = chainAsset
        self.stakingType = stakingType
        self.dashboardRepository = dashboardRepository
        self.stakeStateSource = stakeStateSource
        self.maxApyOperationFactory = maxApyOperationFactory
        self.yieldOperationFactory = yieldOperationFactory
        self.cataloguePricing = cataloguePricing
        self.workingQueue = workingQueue
        self.operationQueue = operationQueue

        super.init(logger: logger)
    }

    override func performSyncUp() {
        seedRootYields()
        seedSubnetYields()
        cataloguePricing.seed()

        stakeStateSubscription.subscribe(refreshing: true)

        performMaxApyFetch()
    }

    override func stopSyncUp() {
        isSyncCompletionDeferred = false
        maxApyCallStore.cancel()
        rootYieldsCallStore.cancel()
        requestedRootHotkeys = nil
        subnetYieldsCallStore.cancel()
        requestedSubnetNetuids = nil
        cataloguePricing.cancel()
        stakeStateSubscription.unsubscribe()
    }

    // throttle() skips stopSyncUp() when a fetch already completed, so the storage
    // subscriptions must be released here as well
    override func deactivate() {
        rootYields = nil
        subnetYields = [:]
        cataloguePricing.reset()

        stopSyncUp()
    }

    private func handle(state: Multistaking.SubtensorState) {
        seedSubnetYields()
        persistState(state)

        if !state.hasActiveStaking {
            performMaxApyFetch()
        }

        performRootYieldsFetch()
        performSubnetYieldsFetch()
        performCataloguePricingRefresh()
    }

    private func performMaxApyFetch() {
        guard !maxApyCallStore.hasCall else {
            return
        }

        executeCancellable(
            wrapper: maxApyOperationFactory.createMaxApyWrapper(),
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

    private func completeSync(_ error: Error?, for state: Multistaking.SubtensorState) {
        let isAwaitingMaxApy = !state.hasActiveStaking && maxApyUpdate == .keep && maxApyCallStore.hasCall
        let isAwaitingSubnetYields = state.rootStakeInRao == nil &&
            !state.heldSubnetNetuids.isSubset(of: subnetYields.keys) && subnetYieldsCallStore.hasCall

        isSyncCompletionDeferred = error == nil && (isAwaitingMaxApy || isAwaitingSubnetYields)

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
            let yields = yieldOperationFactory.cachedAlphaYields(for: SubtensorPallet.rootNetuid).value else {
            return
        }

        rootYields = yields
    }

    private func performRootYieldsFetch() {
        guard let lastState else {
            return
        }

        let hotkeys = Set(
            lastState.positions.filter { $0.netuid == SubtensorPallet.rootNetuid }.map(\.hotkey)
        )

        guard !hotkeys.isEmpty, hotkeys != requestedRootHotkeys else {
            return
        }

        requestedRootHotkeys = hotkeys
        rootYieldsCallStore.cancel()

        executeCancellable(
            wrapper: yieldOperationFactory.createAlphaYieldsWrapper(for: SubtensorPallet.rootNetuid),
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

    private func seedSubnetYields() {
        guard let lastState, lastState.rootStakeInRao == nil else {
            return
        }

        for netuid in lastState.heldSubnetNetuids where subnetYields[netuid] == nil {
            guard let yields = yieldOperationFactory.cachedAlphaYields(for: netuid).value else {
                continue
            }

            subnetYields[netuid] = yields.droppingUnreliable()
        }
    }

    private func performSubnetYieldsFetch() {
        guard let lastState, lastState.rootStakeInRao == nil else {
            return
        }

        let netuids = lastState.heldSubnetNetuids

        guard !netuids.isEmpty, netuids != requestedSubnetNetuids else {
            return
        }

        requestedSubnetNetuids = netuids
        subnetYieldsCallStore.cancel()

        let yieldWrappers = netuids.map { yieldOperationFactory.createAlphaYieldsWrapper(for: $0) }

        let mergeOperation = ClosureOperation<[UInt16: SubtensorAlphaYields]> {
            try yieldWrappers.reduce(into: [:]) { result, wrapper in
                let yields = try wrapper.targetOperation.extractNoCancellableResultData()
                result[yields.netuid] = yields.droppingUnreliable()
            }
        }

        yieldWrappers.forEach { mergeOperation.addDependency($0.targetOperation) }

        executeCancellable(
            wrapper: CompoundOperationWrapper(
                targetOperation: mergeOperation,
                dependencies: yieldWrappers.flatMap(\.allOperations)
            ),
            inOperationQueue: operationQueue,
            backingCallIn: subnetYieldsCallStore,
            runningCallbackIn: workingQueue,
            mutex: mutex
        ) { [weak self] result in
            switch result {
            case let .success(yields):
                self?.updateSubnetYields(yields)
            case let .failure(error):
                self?.logger.warning("Subnet yields fetch error: \(error)")
                self?.completeDeferredSync()
            }
        }
    }

    private func updateSubnetYields(_ newSubnetYields: [UInt16: SubtensorAlphaYields]) {
        guard newSubnetYields != subnetYields else {
            completeDeferredSync()
            return
        }

        subnetYields = newSubnetYields

        persistLastStateIfIdle()
    }

    private func persistLastStateIfIdle(marksSyncing: Bool = true) {
        guard let lastState, !stakeStateSubscription.isFetching else {
            return
        }

        if marksSyncing {
            markSyncingImmediate()
        }

        persistState(lastState)
    }

    private func performCataloguePricingRefresh() {
        cataloguePricing.refresh(
            latestState: { [weak self] in self?.lastState },
            runningCallbackIn: workingQueue,
            mutex: mutex,
            onUpdate: { [weak self] didChange in
                if didChange {
                    self?.persistLastStateIfIdle(marksSyncing: false)
                }
            }
        )
    }

    private func persistState(_ state: Multistaking.SubtensorState) {
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
            rootRate: SubtensorStakeRateCalculator.rootRate(
                of: state.positions.filter { $0.netuid == SubtensorPallet.rootNetuid },
                in: rootYields
            ),
            subnetRate: SubtensorStakeRateCalculator.subnetRate(
                of: state.positions.filter { $0.netuid != SubtensorPallet.rootNetuid },
                in: subnetYields,
                prices: cataloguePricing.alphaPrices
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

        requestedRootHotkeys = nil
        requestedSubnetNetuids = nil

        performMaxApyFetch()
        stakeStateSubscription.refresh()
    }

    func refreshMaxApy() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard isActive, lastState?.hasActiveStaking != true else {
            return
        }

        performMaxApyFetch()
    }
}
