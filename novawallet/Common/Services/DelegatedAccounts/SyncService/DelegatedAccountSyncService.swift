import Foundation
import Operation_iOS

protocol DelegatedAccountSyncServiceProtocol: ObservableSyncServiceProtocol, ApplicationServiceProtocol {
    func updateWalletsStatuses()
}

typealias DelegatedAccountSyncChainWalletFilter = (MetaAccountModel) -> Bool

final class DelegatedAccountSyncService: ObservableSyncService {
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue
    let workingQueue: DispatchQueue
    let metaAccountsRepository: AnyDataProviderRepository<ManagedMetaAccountModel>
    let syncFactory: DelegatedAccountSyncFactoryProtocol
    let walletUpdateMediator: WalletUpdateMediating
    let eventCenter: EventCenterProtocol

    let chainFilter: ChainFilterStrategy
    let chainWalletFilter: DelegatedAccountSyncChainWalletFilter?

    private let callStore = CancellableCallStore()

    private var supportedChainIds: Set<ChainModel.Id> = []

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
        chainWalletFilter: DelegatedAccountSyncChainWalletFilter?,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.chainRegistry = chainRegistry
        self.walletUpdateMediator = walletUpdateMediator
        self.workingQueue = workingQueue
        self.operationQueue = operationQueue
        self.eventCenter = eventCenter
        self.metaAccountsRepository = metaAccountsRepository
        self.chainFilter = chainFilter
        self.chainWalletFilter = chainWalletFilter

        syncFactory = DelegatedAccountSyncFactory(
            chainRegistry: chainRegistry,
            operationQueue: operationQueue,
            logger: logger
        )

        super.init()

        subscribeChains()
    }

    override func performSyncUp() {
        callStore.cancel()

        guard !supportedChainIds.isEmpty else {
            logger.debug("No chains to sync")
            completeImmediate(nil)
            return
        }

        logger.debug("Will start sync for chains: \(supportedChainIds.count)")

        let metaAccountsWrapper = createWalletsWrapper(for: chainWalletFilter)

        let changesWrapper = syncFactory.createSyncWrapper(
            for: supportedChainIds,
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
                self?.logger.debug("Did complete sync \(update)")

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
            guard let self else {
                return
            }

            mutex.lock()

            defer { mutex.unlock() }

            self.handleChain(changes: changes)
        }
    }

    func handleChain(changes: [DataProviderChange<ChainModel>]) {
        let newChainIds = changes.reduce(into: supportedChainIds) { accum, change in
            switch change {
            case let .insert(newItem), let .update(newItem):
                accum.insert(newItem.chainId)
            case let .delete(deletedIdentifier):
                accum.remove(deletedIdentifier)
            }
        }

        guard isActive, newChainIds != supportedChainIds else { return }

        supportedChainIds = newChainIds

        isSyncing = true
        performSyncUp()
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
}
