import Foundation
import SubstrateSdk
import Operation_iOS

final class SubtensorStakedBalanceUpdatingService: BaseSyncService {
    let accountId: AccountId
    let chainAsset: ChainAsset
    let repository: AnyDataProviderRepository<SubtensorStakedBalance>
    let stakeStateSource: SubtensorStakeStateSource
    let cataloguePricing: SubtensorCataloguePricingTracker
    let workingQueue: DispatchQueue
    let operationQueue: OperationQueue

    private lazy var stakeStateSubscription = SubtensorStakeStateSubscription(
        source: stakeStateSource,
        mutex: mutex,
        operationQueue: operationQueue,
        workingQueue: workingQueue,
        onSyncing: { [weak self] in self?.markSyncingImmediate() },
        onState: { [weak self] in self?.persistPricedState($0) },
        onFailure: { [weak self] in self?.completeImmediate($0) },
        onUnchangedState: { [weak self] in self?.repriceState($0) }
    )

    init(
        accountId: AccountId,
        chainAsset: ChainAsset,
        repository: AnyDataProviderRepository<SubtensorStakedBalance>,
        stakeStateSource: SubtensorStakeStateSource,
        cataloguePricing: SubtensorCataloguePricingTracker,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue,
        logger: LoggerProtocol
    ) {
        self.accountId = accountId
        self.chainAsset = chainAsset
        self.repository = repository
        self.stakeStateSource = stakeStateSource
        self.cataloguePricing = cataloguePricing
        self.workingQueue = workingQueue
        self.operationQueue = operationQueue

        super.init(logger: logger)
    }

    override func performSyncUp() {
        stakeStateSubscription.subscribe()
    }

    override func stopSyncUp() {
        cataloguePricing.cancel()
        stakeStateSubscription.unsubscribe()
    }

    // throttle() skips stopSyncUp() when a fetch already completed, so the storage
    // subscriptions must be released here as well
    override func deactivate() {
        stopSyncUp()
    }

    private func persistPricedState(_ state: Multistaking.SubtensorState) {
        guard state.subnetCount > 0 else {
            persistState(state)
            return
        }

        refreshPricing { _ in true }
    }

    private func repriceState(_ state: Multistaking.SubtensorState) {
        guard state.subnetCount > 0 else {
            return
        }

        refreshPricing { [weak self] didChange in
            didChange || self?.stakeStateSubscription.lastState != state
        }
    }

    private func refreshPricing(persistingWhen shouldPersist: @escaping (Bool) -> Bool) {
        cataloguePricing.refresh(
            latestState: { [weak self] in self?.stakeStateSubscription.lastState },
            runningCallbackIn: workingQueue,
            mutex: mutex,
            onUpdate: { [weak self] didChange in
                guard let self, shouldPersist(didChange), let lastState = stakeStateSubscription.lastState else {
                    return
                }

                persistState(lastState)
            }
        )
    }

    private func persistState(_ state: Multistaking.SubtensorState) {
        stakeStateSubscription.save(createSaveWrapper(for: state)) { [weak self] in
            self?.completeImmediate($0)
        }
    }
}

private extension SubtensorStakedBalanceUpdatingService {
    func createSaveWrapper(for state: Multistaking.SubtensorState) -> CompoundOperationWrapper<Void> {
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
