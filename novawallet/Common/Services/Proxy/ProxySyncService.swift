import Foundation
import RobinHood

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
}

final class ProxySyncService {
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue
    let workingQueue: DispatchQueue
    let logger: LoggerProtocol
    let userDataStorageFacade: StorageFacadeProtocol
    let proxyOperationFactory: ProxyOperationFactoryProtocol
    let chainsFilter: (ChainModel) -> Bool
    let metaAccountsRepository: AnyDataProviderRepository<ManagedMetaAccountModel>

    private(set) var isActive: Bool = false

    private(set) var updaters: [ChainModel.Id: ObservableSyncServiceProtocol & ApplicationServiceProtocol] = [:]
    private let mutex = NSLock()

    private var stateObserver = Observable<ProxySyncServiceState>(state: [:])

    init(
        chainRegistry: ChainRegistryProtocol,
        userDataStorageFacade: StorageFacadeProtocol,
        proxyOperationFactory: ProxyOperationFactoryProtocol,
        metaAccountsRepository: AnyDataProviderRepository<ManagedMetaAccountModel>,
        operationQueue: OperationQueue = OperationManagerFacade.assetsRepositoryQueue,
        workingQueue: DispatchQueue = DispatchQueue(
            label: "com.nova.wallet.proxy.sync",
            qos: .userInitiated,
            attributes: .concurrent
        ),
        logger: LoggerProtocol = Logger.shared,
        chainsFilter: ((ChainModel) -> Bool)? = nil
    ) {
        self.chainRegistry = chainRegistry
        self.userDataStorageFacade = userDataStorageFacade
        self.proxyOperationFactory = proxyOperationFactory
        self.workingQueue = workingQueue
        self.operationQueue = operationQueue
        self.logger = logger
        self.metaAccountsRepository = metaAccountsRepository
        self.chainsFilter = chainsFilter ?? { $0.hasProxy }
        subscribeChains()
    }

    private func subscribeChains() {
        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: workingQueue
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
        if !chainsFilter(chain) {
            stopSyncSevice(for: chain.chainId)
            return
        }
        guard updaters[chain.chainId] == nil else {
            return
        }

        let service = ChainProxySyncService(
            chainModel: chain,
            metaAccountsRepository: metaAccountsRepository,
            chainRegistry: chainRegistry,
            proxyOperationFactory: proxyOperationFactory,
            eventCenter: EventCenter.shared,
            operationQueue: operationQueue,
            workingQueue: workingQueue
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
                if let chainAccount = item.info.chainAccounts.first(where: { $0.proxy != nil }),
                   let proxy = chainAccount.proxy {
                    result[item] = chainAccount
                }
            }
        }
        proxiesOperation.addDependency(walletsOperation)

        let saveOperation = metaAccountsRepository.saveOperation({
            let proxies = try proxiesOperation.extractNoCancellableResultData()
            return proxies.map {
                $0.key.replacingInfo($0.key.info.replacingChainAccount($0.value.replacingProxyStatus(from: .new, to: .active)))
            }.compactMap { $0 }
        }, {
            let proxies = try proxiesOperation.extractNoCancellableResultData()
            return proxies
                .filter { $0.value.proxy?.status == .revoked }
                .map(\.key.identifier)
                .compactMap { $0 }
        })
        saveOperation.addDependency(proxiesOperation)

        let wrapper = CompoundOperationWrapper(
            targetOperation: saveOperation,
            dependencies: [proxiesOperation, walletsOperation]
        )

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case .success:
                self?.logger.debug("Proxy statuses were updated")
            case let .failure(error):
                self?.logger.error(error.localizedDescription)
            }
        }
    }

    func syncUp() {
        updaters.values.forEach { $0.syncUp() }
    }
}
