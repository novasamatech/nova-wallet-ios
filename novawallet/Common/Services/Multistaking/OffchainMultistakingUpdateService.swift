import Foundation
import RobinHood

protocol OffchainMultistakingUpdateServiceProtocol: ObservableSyncServiceProtocol, ApplicationServiceProtocol {
    func apply(newChainAssets: Set<ChainAsset>)
}

final class OffchainMultistakingUpdateService: ObservableSyncService, AnyCancellableCleaning,
    OffchainMultistakingUpdateServiceProtocol {
    let wallet: MetaAccountModel
    let accountResolveProvider: StreamableProvider<Multistaking.ResolvedAccount>
    let dashboardRepository: AnyDataProviderRepository<Multistaking.DashboardItemOffchainPart>
    let operationFactory: MultistakingOffchainOperationFactoryProtocol
    let workingQueue: DispatchQueue
    let operationQueue: OperationQueue
    let syncDelay: TimeInterval

    private var pendingOperation: CancellableCall?
    private var resolvedAccounts: [Multistaking.Option: Multistaking.ResolvedAccount] = [:]
    private var chainAssets: Set<ChainAsset> = []

    init(
        wallet: MetaAccountModel,
        accountResolveProvider: StreamableProvider<Multistaking.ResolvedAccount>,
        dashboardRepository: AnyDataProviderRepository<Multistaking.DashboardItemOffchainPart>,
        operationFactory: MultistakingOffchainOperationFactoryProtocol,
        workingQueue: DispatchQueue,
        operationQueue: OperationQueue,
        syncDelay: TimeInterval = 2,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.wallet = wallet
        self.accountResolveProvider = accountResolveProvider
        self.dashboardRepository = dashboardRepository
        self.operationFactory = operationFactory
        self.workingQueue = workingQueue
        self.operationQueue = operationQueue
        self.syncDelay = syncDelay

        super.init(logger: logger)

        subscribeAccounts(for: wallet)
    }

    func apply(newChainAssets: Set<ChainAsset>) {
        guard newChainAssets != chainAssets else {
            return
        }

        chainAssets = newChainAssets

        syncUp(afterDelay: syncDelay, ignoreIfSyncing: false)
    }

    override func performSyncUp() {
        cancelOperation()

        guard !chainAssets.isEmpty else {
            completeImmediate(nil)
            return
        }

        performSyncUpInternal()
    }

    override func stopSyncUp() {
        cancelOperation()
    }

    private func performSyncUpInternal() {
        logger?.debug("Will start syncing...")

        let resolvedAccountIds = resolvedAccounts.mapValues { $0.resolvedAccountId }

        let wrapper = operationFactory.createWrapper(
            from: wallet,
            resolvedAccounts: resolvedAccountIds,
            chainAssets: chainAssets
        )

        let walletId = wallet.metaId

        let saveOperation = dashboardRepository.saveOperation({
            let allStakingItems = try wrapper.targetOperation.extractNoCancellableResultData()

            let entities = allStakingItems.map { stakingItem in
                let chainAssetId = ChainAssetId(
                    chainId: stakingItem.chainId,
                    assetId: AssetModel.utilityAssetId
                )

                let stakingOption = Multistaking.OptionWithWallet(
                    walletId: walletId,
                    option: .init(chainAssetId: chainAssetId, type: stakingItem.stakingType)
                )

                let hasAssignedStake = stakingItem.state == .active

                return Multistaking.DashboardItemOffchainPart(
                    stakingOption: stakingOption,
                    maxApy: stakingItem.maxApy,
                    hasAssignedStake: hasAssignedStake,
                    totalRewards: stakingItem.totalRewards
                )
            }

            return Array(entities)
        }, {
            []
        })

        saveOperation.addDependency(wrapper.targetOperation)

        saveOperation.completionBlock = { [weak self] in
            self?.workingQueue.async {
                do {
                    self?.logger?.debug("Did save synced data...")
                    _ = try saveOperation.extractNoCancellableResultData()

                    self?.complete(nil)
                } catch {
                    self?.complete(error)
                }
            }
        }

        let compoundWrapper = CompoundOperationWrapper(
            targetOperation: saveOperation,
            dependencies: wrapper.allOperations
        )

        pendingOperation = compoundWrapper

        operationQueue.addOperations(compoundWrapper.allOperations, waitUntilFinished: false)
    }

    private func cancelOperation() {
        logger?.debug("Cancelling syncing...")

        clear(cancellable: &pendingOperation)
    }

    private func subscribeAccounts(for wallet: MetaAccountModel) {
        let updateClosure: ([DataProviderChange<Multistaking.ResolvedAccount>]) -> Void
        updateClosure = { [weak self] changes in
            guard let self = self else {
                return
            }

            self.mutex.lock()

            let shouldSyncup = self.handleAccountChanges(changes, wallet: wallet)

            self.mutex.unlock()

            if shouldSyncup {
                self.syncUp(afterDelay: self.syncDelay, ignoreIfSyncing: false)
            }
        }

        let failureClosure: (Error) -> Void = { [weak self] _ in
            self?.logger?.error("Can' retrive resolved accounts")
        }

        let options = StreamableProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )

        accountResolveProvider.addObserver(
            self,
            deliverOn: workingQueue,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }

    private func handleAccountChanges(
        _ changes: [DataProviderChange<Multistaking.ResolvedAccount>],
        wallet: MetaAccountModel
    ) -> Bool {
        logger?.debug("Did receive staking accounts: \(changes.count)")

        var newAccounts = resolvedAccounts

        newAccounts = changes.reduce(into: newAccounts) { result, change in
            switch change {
            case let .insert(newItem), let .update(newItem):
                if
                    wallet.has(
                        accountId: newItem.walletAccountId,
                        chainId: newItem.stakingOption.chainAssetId.chainId
                    ) {
                    result[newItem.stakingOption] = newItem
                }
            case let .delete(deletedIdentifier):
                // it is a rare operation so it is ok to have it O(n)
                result = result.filter { $0.value.identifier != deletedIdentifier }
            }
        }

        if newAccounts != resolvedAccounts {
            resolvedAccounts = newAccounts

            return isActive && !chainAssets.isEmpty
        } else {
            return false
        }
    }
}
