import Foundation
import RobinHood

protocol OffchainMultistakingUpdateServiceProtocol {
    func apply(newChainAssets: Set<ChainAsset>)
}

final class OffchainMultistakingUpdateService: BaseSyncService, AnyCancellableCleaning {
    let wallet: MetaAccountModel
    let accountResolveProvider: StreamableProvider<Multistaking.ResolvedAccount>
    let dashboardRepository: AnyDataProviderRepository<Multistaking.DashboardItemOffchainPart>
    let operationFactory: MultistakingOffchainOperationFactoryProtocol
    let operationQueue: OperationQueue
    let syncDelay: TimeInterval

    @Atomic(defaultValue: nil) private var pendingOperation: CancellableCall?
    @Atomic(defaultValue: [:]) private var resolvedAccounts: [Multistaking.Option: Multistaking.ResolvedAccount]
    @Atomic(defaultValue: []) private var chainAssets: Set<ChainAsset>

    init(
        wallet: MetaAccountModel,
        accountResolveProvider: StreamableProvider<Multistaking.ResolvedAccount>,
        dashboardRepository: AnyDataProviderRepository<Multistaking.DashboardItemOffchainPart>,
        operationFactory: MultistakingOffchainOperationFactoryProtocol,
        operationQueue: OperationQueue,
        syncDelay: TimeInterval = 2,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.wallet = wallet
        self.accountResolveProvider = accountResolveProvider
        self.dashboardRepository = dashboardRepository
        self.operationFactory = operationFactory
        self.operationQueue = operationQueue
        self.syncDelay = syncDelay

        super.init(logger: logger)

        subscribeAccounts()
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
            do {
                _ = try saveOperation.extractNoCancellableResultData()

                self?.complete(nil)
            } catch {
                self?.complete(error)
            }
        }

        let compoundWrapper = CompoundOperationWrapper(
            targetOperation: saveOperation,
            dependencies: wrapper.allOperations
        )

        pendingOperation = compoundWrapper

        operationQueue.addOperations(compoundWrapper.allOperations, waitUntilFinished: false)
    }

    override func stopSyncUp() {
        cancelOperation()
    }

    private func cancelOperation() {
        clear(cancellable: &pendingOperation)
    }

    private func subscribeAccounts() {
        let updateClosure: ([DataProviderChange<Multistaking.ResolvedAccount>]) -> Void
        updateClosure = { [weak self] changes in
            guard var newAccounts = self?.resolvedAccounts else {
                return
            }

            newAccounts = changes.reduce(into: newAccounts) { result, change in
                switch change {
                case let .insert(newItem), let .update(newItem):
                    result[newItem.stakingOption] = newItem
                case let .delete(deletedIdentifier):
                    // it is a rare operation so it is ok to have it O(n)
                    result = result.filter { $0.value.identifier != deletedIdentifier }
                }
            }

            if newAccounts != self?.resolvedAccounts {
                self?.resolvedAccounts = newAccounts

                self?.scheduleSyncAfterAccountsChange()
            }

            return
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
            deliverOn: .global(qos: .default),
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }

    private func scheduleSyncAfterAccountsChange() {
        guard isActive, !chainAssets.isEmpty else {
            return
        }

        syncUp(afterDelay: syncDelay, ignoreIfSyncing: false)
    }
}
