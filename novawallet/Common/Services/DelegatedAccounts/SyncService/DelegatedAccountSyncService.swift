import Foundation
import Operation_iOS

typealias DelegatedAccountSyncServiceState = [ChainModel.Id: Bool]
typealias DelegatedAccountUpdater = DelegatedAccountChainSyncServiceProtocol & ApplicationServiceProtocol

protocol DelegatedAccountSyncServiceProtocol: ApplicationServiceProtocol {
    func subscribeSyncState(
        _ target: AnyObject,
        queue: DispatchQueue?,
        closure: @escaping (DelegatedAccountSyncServiceState, DelegatedAccountSyncServiceState) -> Void
    )

    func unsubscribeSyncState(_ target: AnyObject)
    func updateWalletsStatuses()
    func syncUp()
    func syncUp(
        chainId: ChainModel.Id,
        blockHash: Data?
    )
}

typealias DelegatedAccountSyncChainFilter = (ChainModel) -> Bool
typealias DelegatedAccountSyncChainWalletFilter = (ChainModel, MetaAccountModel) -> Bool

final class DelegatedAccountSyncService {
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue
    let workingQueue: DispatchQueue
    let logger: LoggerProtocol
    let proxyOperationFactory: ProxyOperationFactoryProtocol
    let metaAccountsRepository: AnyDataProviderRepository<ManagedMetaAccountModel>
    let walletUpdateMediator: WalletUpdateMediating
    let eventCenter: EventCenterProtocol

    let chainFilter: ChainFilterStrategy
    let chainWalletFilter: DelegatedAccountSyncChainWalletFilter?

    private(set) var isActive: Bool = false

    private(set) var updaters: [ChainModel.Id: DelegatedAccountUpdater] = [:]
    private let mutex = NSLock()

    private var stateObserver = Observable<DelegatedAccountSyncServiceState>(state: [:])

    init(
        chainRegistry: ChainRegistryProtocol,
        proxyOperationFactory: ProxyOperationFactoryProtocol,
        metaAccountsRepository: AnyDataProviderRepository<ManagedMetaAccountModel>,
        walletUpdateMediator: WalletUpdateMediating,
        operationQueue: OperationQueue = OperationManagerFacade.assetsRepositoryQueue,
        eventCenter: EventCenterProtocol = EventCenter.shared,
        workingQueue: DispatchQueue = DispatchQueue(
            label: "com.nova.wallet.delegatedAccount.sync",
            qos: .userInitiated,
            attributes: .concurrent
        ),
        logger: LoggerProtocol = Logger.shared,
        chainFilter: ChainFilterStrategy,
        chainWalletFilter: DelegatedAccountSyncChainWalletFilter?
    ) {
        self.chainRegistry = chainRegistry
        self.proxyOperationFactory = proxyOperationFactory
        self.walletUpdateMediator = walletUpdateMediator
        self.workingQueue = workingQueue
        self.operationQueue = operationQueue
        self.logger = logger
        self.eventCenter = eventCenter
        self.metaAccountsRepository = metaAccountsRepository
        self.chainFilter = chainFilter
        self.chainWalletFilter = chainWalletFilter

        subscribeChains()
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
        let barrier = DelegatedAccountSyncBarrier()

        changes.forEach { change in
            switch change {
            case let .insert(newItem), let .update(newItem):
                setupSyncService(for: newItem, barrier: barrier)
            case let .delete(deletedIdentifier):
                stopSyncSevice(for: deletedIdentifier)
            }
        }
    }

    func stopSyncSevice(for chainId: ChainModel.Id) {
        updaters[chainId]?.stopSyncUp()
        updaters[chainId] = nil
    }

    func setupSyncService(
        for chain: ChainModel,
        barrier: DelegatedAccountSyncBarrierProtocol
    ) {
        guard updaters[chain.chainId] == nil else {
            return
        }

        let service = DelegatedAccountChainSyncService(
            chainModel: chain,
            walletUpdateMediator: walletUpdateMediator,
            metaAccountsRepository: metaAccountsRepository,
            chainRegistry: chainRegistry,
            eventCenter: eventCenter,
            operationQueue: operationQueue,
            workingQueue: workingQueue,
            chainWalletFilter: chainWalletFilter,
            uniqueUpdatesBarrier: barrier
        )

        updaters[chain.chainId] = service
        addSyncHandler(for: service, chainId: chain.chainId)

        if isActive {
            service.setup()
        }
    }

    func removeOnchainSyncHandler() {
        updaters.values.forEach { $0.unsubscribeSyncState(self) }
    }

    func addSyncHandler(for service: ObservableSyncServiceProtocol, chainId: ChainModel.Id) {
        service.subscribeSyncState(
            self,
            queue: workingQueue
        ) { [weak self] _, newState in
            guard let self = self else {
                return
            }

            self.mutex.lock()

            self.stateObserver.state.updateValue(newState, forKey: chainId)

            self.mutex.unlock()
        }
    }
}

// MARK: DelegatedAccountSyncServiceProtocol

extension DelegatedAccountSyncService: DelegatedAccountSyncServiceProtocol {
    func subscribeSyncState(
        _ target: AnyObject,
        queue: DispatchQueue?,
        closure: @escaping (DelegatedAccountSyncServiceState, DelegatedAccountSyncServiceState) -> Void
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        let state = stateObserver.state

        dispatchInQueueWhenPossible(queue) {
            closure(state, state)
        }

        stateObserver.addObserver(with: target, queue: queue, closure: closure)
    }

    func unsubscribeSyncState(_ target: AnyObject) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        stateObserver.removeObserver(by: target)
    }

    func setup() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard !isActive else {
            return
        }

        isActive = true

        updaters.values.forEach { $0.setup() }
    }

    func throttle() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard isActive else {
            return
        }

        isActive = false

        updaters.values.forEach { $0.throttle() }
    }

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

    func syncUp() {
        updaters.values.forEach { $0.syncUp() }
    }

    func syncUp(
        chainId: ChainModel.Id,
        blockHash: Data?
    ) {
        updaters[chainId]?.sync(at: blockHash)
    }
}
