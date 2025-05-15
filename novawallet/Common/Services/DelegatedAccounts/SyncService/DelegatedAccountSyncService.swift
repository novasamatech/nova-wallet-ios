import Foundation
import Operation_iOS

protocol DelegatedAccountSyncServiceProtocol: ObservableSyncServiceProtocol, ApplicationServiceProtocol {
    func updateWalletsStatuses()
    func syncUp(
        chainId: ChainModel.Id,
        at blockHash: Data?
    )
}

typealias DelegatedAccountSyncChainWalletFilter = (MetaAccountModel) -> Bool

final class DelegatedAccountSyncService: ObservableSyncService {
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue
    let workingQueue: DispatchQueue
    let metaAccountsRepository: AnyDataProviderRepository<ManagedMetaAccountModel>
    let updatesOperationFactory: CompoundDelegatedAccountFetchOperationFactory
    let walletUpdateMediator: WalletUpdateMediating
    let eventCenter: EventCenterProtocol

    let chainFilter: ChainFilterStrategy
    let chainWalletFilter: DelegatedAccountSyncChainWalletFilter?

    private let callStore = CancellableCallStore()

    init(
        chainRegistry: ChainRegistryProtocol,
        metaAccountsRepository: AnyDataProviderRepository<ManagedMetaAccountModel>,
        walletUpdateMediator: WalletUpdateMediating,
        operationQueue: OperationQueue = OperationManagerFacade.assetsRepositoryQueue,
        eventCenter: EventCenterProtocol = EventCenter.shared,
        workingQueue: DispatchQueue = DispatchQueue(
            label: "com.nova.wallet.delegatedAccount.sync",
            qos: .userInitiated,
            attributes: .concurrent
        ),
        chainFilter: ChainFilterStrategy,
        chainWalletFilter: DelegatedAccountSyncChainWalletFilter?
    ) {
        self.chainRegistry = chainRegistry
        self.walletUpdateMediator = walletUpdateMediator
        self.workingQueue = workingQueue
        self.operationQueue = operationQueue
        self.eventCenter = eventCenter
        self.metaAccountsRepository = metaAccountsRepository
        self.chainFilter = chainFilter
        self.chainWalletFilter = chainWalletFilter

        updatesOperationFactory = DelegatedAccountFetchOperationFactory(
            operationQueue: operationQueue
        )

        super.init()

        subscribeChains()
    }

    override func performSyncUp() {
        performSync(for: nil, at: nil)
    }

    override func stopSyncUp() {
        callStore.cancel()
    }
}

// MARK: Private

private extension DelegatedAccountSyncService {
    func subscribeChains() {
        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: workingQueue,
            filterStrategy: chainFilter
        ) { [weak self] changes in
            guard let self = self else {
                return
            }

            self.mutex.lock()

            self.handleChain(changes: changes)

            self.mutex.unlock()
        }
    }

    func handleChain(changes: [DataProviderChange<ChainModel>]) {
        changes.forEach { change in
            switch change {
            case let .insert(newItem), let .update(newItem):
                setupSyncFactory(for: newItem)
            case let .delete(deletedIdentifier):
                stopSyncSevice(for: deletedIdentifier)
            }
        }

        guard isActive, !changes.isEmpty else { return }

        performSyncUp()
    }

    func stopSyncSevice(for chainId: ChainModel.Id) {
        updatesOperationFactory.removeChainFactory(for: chainId)
    }

    func setupSyncFactory(for chain: ChainModel) {
        guard !updatesOperationFactory.supportsChain(with: chain.chainId) else {
            return
        }

        let factory = ChainDelegatedAccountFetchOperationFactory(
            chainModel: chain,
            metaAccountsRepository: metaAccountsRepository,
            chainRegistry: chainRegistry,
            operationQueue: operationQueue,
            chainWalletFilter: chainWalletFilter
        )

        updatesOperationFactory.addChainFactory(factory, for: chain.chainId)
    }

    func performSync(
        for chainId: ChainModel.Id?,
        at blockHash: Data?
    ) {
        callStore.cancel()

        let metaAccountsWrapper = createWalletsWrapper(for: chainWalletFilter)

        let changesWrapper = updatesOperationFactory.createChangesWrapper(
            for: chainId,
            at: blockHash,
            metaAccountsClosure: { try metaAccountsWrapper.targetOperation.extractNoCancellableResultData() }
        )

        let updateWrapper = walletUpdateMediator.saveChanges {
            let changes = try changesWrapper.targetOperation.extractNoCancellableResultData()

            return changes
        }

        changesWrapper.addDependency(wrapper: metaAccountsWrapper)
        updateWrapper.addDependency(wrapper: changesWrapper)

        let resultWrapper = updateWrapper
            .insertingHead(operations: metaAccountsWrapper.allOperations)
            .insertingHead(operations: changesWrapper.allOperations)

        executeCancellable(
            wrapper: resultWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: workingQueue,
            mutex: mutex
        ) { [weak self] result in
            switch result {
            case let .success(update):
                DispatchQueue.main.async {
                    self?.eventCenter.notify(with: WalletsChanged(source: .byProxyService))

                    if update.isWalletSwitched {
                        self?.eventCenter.notify(with: SelectedWalletSwitched())
                    }
                }
                self?.completeImmediate(nil)
            case let .failure(error):
                self?.completeImmediate(error)
            }
        }
    }

    func createWalletsWrapper(
        for filter: DelegatedAccountSyncChainWalletFilter?
    ) -> CompoundOperationWrapper<[ManagedMetaAccountModel]> {
        let metaAccountsOperation = metaAccountsRepository.fetchAllOperation(with: .init())

        let filterOperation = ClosureOperation<[ManagedMetaAccountModel]> {
            let allWallets = try metaAccountsOperation.extractNoCancellableResultData()

            guard let filter else {
                return allWallets
            }

            return allWallets.filter { filter($0.info) }
        }

        filterOperation.addDependency(metaAccountsOperation)

        return CompoundOperationWrapper(
            targetOperation: filterOperation,
            dependencies: [metaAccountsOperation]
        )
    }
}

// MARK: DelegatedAccountSyncServiceProtocol

extension DelegatedAccountSyncService: DelegatedAccountSyncServiceProtocol {
    func updateWalletsStatuses() {
        let walletsOperation = metaAccountsRepository.fetchAllOperation(with: .init())

        let delegatedAccountsOperation: ClosureOperation<[ManagedMetaAccountModel]> = .init {
            try walletsOperation.extractNoCancellableResultData().filter { $0.info.isDelegated() }
        }

        delegatedAccountsOperation.addDependency(walletsOperation)

        let walletUpdateWrapper = walletUpdateMediator.saveChanges {
            let delegatedAccounts = try delegatedAccountsOperation.extractNoCancellableResultData()

            let updated = delegatedAccounts.map { delegatedAccount in
                let updatedInfo = delegatedAccount.info.replacingDelegatedAccountStatus(
                    from: .new,
                    to: .active
                )

                return delegatedAccount.replacingInfo(updatedInfo)
            }

            let removed = delegatedAccounts.filter { $0.info.delegatedAccountStatus() == .revoked }

            return SyncChanges(newOrUpdatedItems: updated, removedItems: removed)
        }

        walletUpdateWrapper.addDependency(operations: [delegatedAccountsOperation])

        let compoundWrapper = CompoundOperationWrapper(
            targetOperation: walletUpdateWrapper.targetOperation,
            dependencies: [walletsOperation, delegatedAccountsOperation] + walletUpdateWrapper.dependencies
        )

        execute(
            wrapper: compoundWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { result in
            switch result {
            case let .success(update):
                if update.isWalletSwitched {
                    self.eventCenter.notify(with: SelectedWalletSwitched())
                }

                self.logger.debug("Delegated accounts statuses updated")
            case let .failure(error):
                self.logger.error("Did fail to update delegated accounts statuses: \(error)")
            }
        }
    }

    func syncUp(
        chainId: ChainModel.Id,
        at blockHash: Data?
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard isActive else {
            return
        }

        if isSyncing {
            stopSyncUp()

            isSyncing = false
        }

        isSyncing = true

        performSync(for: chainId, at: blockHash)
    }
}
