import Foundation
import Operation_iOS

typealias ProxySyncServiceState = [ChainModel.Id: Bool]

protocol ProxySyncServiceProtocol: ApplicationServiceProtocol {
    func subscribeSyncState(
        _ target: AnyObject,
        queue: DispatchQueue?,
        closure: @escaping (ProxySyncServiceState, ProxySyncServiceState) -> Void
    )

    func unsubscribeSyncState(_ target: AnyObject)
    func updateWalletsStatuses()
    func syncUp()
    func syncUp(
        chainId: ChainModel.Id,
        blockHash: Data?
    )
}

typealias ProxySyncChainFilter = (ChainModel) -> Bool
typealias ProxySyncChainWalletFilter = (ChainModel, MetaAccountModel) -> Bool

final class ProxySyncService {
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue
    let workingQueue: DispatchQueue
    let logger: LoggerProtocol
    let proxyOperationFactory: ProxyOperationFactoryProtocol
    let metaAccountsRepository: AnyDataProviderRepository<ManagedMetaAccountModel>
    let walletUpdateMediator: WalletUpdateMediating
    let eventCenter: EventCenterProtocol

    let chainFilter: ChainFilterStrategy
    let chainWalletFilter: ProxySyncChainWalletFilter?

    private(set) var isActive: Bool = false

    private(set) var updaters: [ChainModel.Id: ChainProxySyncServiceProtocol & ApplicationServiceProtocol] = [:]
    private let mutex = NSLock()

    private var stateObserver = Observable<ProxySyncServiceState>(state: [:])

    init(
        chainRegistry: ChainRegistryProtocol,
        proxyOperationFactory: ProxyOperationFactoryProtocol,
        metaAccountsRepository: AnyDataProviderRepository<ManagedMetaAccountModel>,
        walletUpdateMediator: WalletUpdateMediating,
        operationQueue: OperationQueue = OperationManagerFacade.assetsRepositoryQueue,
        eventCenter: EventCenterProtocol = EventCenter.shared,
        workingQueue: DispatchQueue = DispatchQueue(
            label: "com.nova.wallet.proxy.sync",
            qos: .userInitiated,
            attributes: .concurrent
        ),
        logger: LoggerProtocol = Logger.shared,
        chainFilter: ChainFilterStrategy,
        chainWalletFilter: ProxySyncChainWalletFilter?
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

    private func subscribeChains() {
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

    private func handleChain(changes: [DataProviderChange<ChainModel>]) {
        changes.forEach { change in
            switch change {
            case let .insert(newItem), let .update(newItem):
                setupSyncService(for: newItem)
            case let .delete(deletedIdentifier):
                stopSyncSevice(for: deletedIdentifier)
            }
        }
    }

    private func stopSyncSevice(for chainId: ChainModel.Id) {
        updaters[chainId]?.stopSyncUp()
        updaters[chainId] = nil
    }

    private func setupSyncService(for chain: ChainModel) {
        guard updaters[chain.chainId] == nil else {
            return
        }

        let service = ChainProxySyncService(
            chainModel: chain,
            walletUpdateMediator: walletUpdateMediator,
            metaAccountsRepository: metaAccountsRepository,
            chainRegistry: chainRegistry,
            proxyOperationFactory: proxyOperationFactory,
            eventCenter: eventCenter,
            operationQueue: operationQueue,
            workingQueue: workingQueue,
            chainWalletFilter: chainWalletFilter
        )

        updaters[chain.chainId] = service
        addSyncHandler(for: service, chainId: chain.chainId)

        if isActive {
            service.setup()
        }
    }

    private func removeOnchainSyncHandler() {
        updaters.values.forEach { $0.unsubscribeSyncState(self) }
    }

    private func addSyncHandler(for service: ObservableSyncServiceProtocol, chainId: ChainModel.Id) {
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

extension ProxySyncService: ProxySyncServiceProtocol {
    func subscribeSyncState(
        _ target: AnyObject,
        queue: DispatchQueue?,
        closure: @escaping (ProxySyncServiceState, ProxySyncServiceState) -> Void
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

        let proxiesOperation: ClosureOperation<[ManagedMetaAccountModel: ChainAccountModel]> = .init {
            let wallets = try walletsOperation.extractNoCancellableResultData()
            return wallets.reduce(into: [ManagedMetaAccountModel: ChainAccountModel]()) { result, item in
                if let chainAccount = item.info.chainAccounts.first(where: { $0.proxy != nil }) {
                    result[item] = chainAccount
                }
            }
        }
        proxiesOperation.addDependency(walletsOperation)

        let walletUpdateWrapper = walletUpdateMediator.saveChanges {
            let proxies = try proxiesOperation.extractNoCancellableResultData()

            let updated = proxies.map {
                $0.key.replacingInfo($0.key.info.replacingChainAccount(
                    $0.value.replacingProxyStatus(from: .new, to: .active)
                ))
            }.compactMap { $0 }

            let removed = proxies
                .filter { $0.value.proxy?.status == .revoked }
                .map(\.key)

            return SyncChanges(newOrUpdatedItems: updated, removedItems: removed)
        }

        walletUpdateWrapper.addDependency(operations: [proxiesOperation])

        let compoundWrapper = CompoundOperationWrapper(
            targetOperation: walletUpdateWrapper.targetOperation,
            dependencies: [walletsOperation, proxiesOperation] + walletUpdateWrapper.dependencies
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

                self.logger.debug("Proxy statuses updated")
            case let .failure(error):
                self.logger.error("Did fail to update proxy statuses: \(error)")
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
