import Foundation
import SubstrateSdk
import Operation_iOS

final class SubtensorStakedBalanceUpdatingService: BaseSyncService {
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

    private lazy var stakeStateSubscription = SubtensorStakeStateSubscription(
        accountId: accountId,
        stakeStateFetchFactory: stakeStateFetchFactory,
        connection: connection,
        runtimeService: runtimeService,
        mutex: mutex,
        operationQueue: operationQueue,
        workingQueue: workingQueue,
        logger: logger,
        onSyncing: { [weak self] in self?.markSyncingImmediate() },
        onState: { [weak self] in self?.persistPricedState($0) },
        onFailure: { [weak self] in self?.completeImmediate($0) }
    )

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
        eventCenter.add(observer: self, dispatchIn: workingQueue)

        stakeStateSubscription.subscribe()
    }

    override func stopSyncUp() {
        cataloguePricing.cancel()
        stakeStateSubscription.unsubscribe()
    }

    // throttle() skips stopSyncUp() when a fetch already completed, so the storage
    // subscriptions must be released here as well
    override func deactivate() {
        eventCenter.remove(observer: self)

        cataloguePricing.cancel()
        stakeStateSubscription.unsubscribe()
    }

    private func persistPricedState(_ state: Multistaking.SubtensorStakingState) {
        guard state.subnetCount > 0 else {
            persistState(state)
            return
        }

        cataloguePricing.refresh(
            latestState: { [weak self] in self?.stakeStateSubscription.lastState },
            runningCallbackIn: workingQueue,
            mutex: mutex,
            onUpdate: { [weak self] _ in
                guard let self, let lastState = stakeStateSubscription.lastState else {
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

        stakeStateSubscription.refresh()
    }
}
