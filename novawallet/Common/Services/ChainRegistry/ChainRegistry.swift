import Foundation
import Operation_iOS
import SubstrateSdk

protocol ChainRegistryProtocol: AnyObject {
    var availableChainIds: Set<ChainModel.Id>? { get }

    func getChain(for chainId: ChainModel.Id) -> ChainModel?
    func getConnection(for chainId: ChainModel.Id) -> ChainConnection?
    func getOneShotConnection(for chainId: ChainModel.Id) -> JSONRPCEngine?

    func getRuntimeProvider(for chainId: ChainModel.Id) -> RuntimeProviderProtocol?
    func switchSync(mode: ChainSyncMode, chainId: ChainModel.Id) throws

    func chainsSubscribe(
        _ target: AnyObject,
        runningInQueue: DispatchQueue,
        filterStrategy: ChainFilterStrategy?,
        updateClosure: @escaping ([DataProviderChange<ChainModel>]) -> Void
    )

    func chainsUnsubscribe(_ target: AnyObject)

    func subscribeChainState(_ subscriber: ConnectionStateSubscription, chainId: ChainModel.Id)
    func unsubscribeChainState(_ subscriber: ConnectionStateSubscription, chainId: ChainModel.Id)

    func syncUp()
}

extension ChainRegistryProtocol {
    func chainsSubscribe(
        _ target: AnyObject,
        runningInQueue: DispatchQueue,
        filterStrategy: ChainFilterStrategy? = nil,
        updateClosure: @escaping ([DataProviderChange<ChainModel>]) -> Void
    ) {
        chainsSubscribe(
            target,
            runningInQueue: runningInQueue,
            filterStrategy: filterStrategy,
            updateClosure: updateClosure
        )
    }
}

final class ChainRegistry {
    struct RuntimeSubscriptionInfo {
        let subscription: SpecVersionSubscriptionProtocol
        let syncMode: ChainSyncMode
    }

    let runtimeProviderPool: RuntimeProviderPoolProtocol
    let connectionPool: ConnectionPoolProtocol
    let chainSyncService: ChainSyncServiceProtocol
    let runtimeSyncService: RuntimeSyncServiceProtocol
    let commonTypesSyncService: CommonTypesSyncServiceProtocol
    let chainProvider: StreamableProvider<ChainModel>
    let specVersionSubscriptionFactory: SpecVersionSubscriptionFactoryProtocol
    let logger: LoggerProtocol?

    private(set) var runtimeVersionSubscriptions: [ChainModel.Id: RuntimeSubscriptionInfo] = [:]
    private var availableChains: [ChainModel.Id: ChainModel] = [:]
    
    private var chainsChangesObservers: [ChainsObserver] = []

    private let mutex = NSLock()

    init(
        runtimeProviderPool: RuntimeProviderPoolProtocol,
        connectionPool: ConnectionPoolProtocol,
        chainSyncService: ChainSyncServiceProtocol,
        runtimeSyncService: RuntimeSyncServiceProtocol,
        commonTypesSyncService: CommonTypesSyncServiceProtocol,
        chainProvider: StreamableProvider<ChainModel>,
        specVersionSubscriptionFactory: SpecVersionSubscriptionFactoryProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.runtimeProviderPool = runtimeProviderPool
        self.connectionPool = connectionPool
        self.chainSyncService = chainSyncService
        self.runtimeSyncService = runtimeSyncService
        self.commonTypesSyncService = commonTypesSyncService
        self.chainProvider = chainProvider
        self.specVersionSubscriptionFactory = specVersionSubscriptionFactory
        self.logger = logger

        subscribeToChains()
    }

    private func subscribeToChains() {
        let updateClosure: ([DataProviderChange<ChainModel>]) -> Void = { [weak self] changes in
            self?.handle(changes: changes)
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.logger?.error("Unexpected error chains listener setup: \(error)")
        }

        let options = StreamableProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false,
            refreshWhenEmpty: false
        )

        chainProvider.addObserver(
            self,
            deliverOn: DispatchQueue.global(qos: .userInitiated),
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }

    private func handle(changes: [DataProviderChange<ChainModel>]) {
        mutex.lock()
        
        defer {
            mutex.unlock()
        }

        guard !changes.isEmpty else {
            return
        }
        
        let chainsBeforeChanges = availableChains

        changes.forEach { change in
            do {
                switch change {
                case let .insert(chain), let .update(chain):
                    availableChains[chain.chainId] = chain

                    try updateSyncMode(for: chain)
                case let .delete(chainId):
                    availableChains[chainId] = nil

                    connectionPool.deactivateConnection(for: chainId)
                    clearRuntimeSubscriptionIfExists(for: chainId)
                    clearRuntimeHandlingIfNeeded(for: chainId)

                    logger?.debug("Cleared runtime for: \(chainId)")
                }
            } catch {
                logger?.error("Unexpected error on handling chains update: \(error)")
            }
        }
        
        chainsChangesObservers.forEach { $0.updateClosure(changes, chainsBeforeChanges) }
    }

    private func updateSyncMode(for chain: ChainModel) throws {
        switch chain.syncMode {
        case .full, .light:
            let connection = try connectionPool.setupConnection(for: chain)

            setupRuntimeHandlingIfNeeded(for: chain, connection: connection)
            setupRuntimeVersionSubscriptionIfNeeded(for: chain, connection: connection)
        case .disabled:
            connectionPool.deactivateConnection(for: chain.chainId)
            clearRuntimeSubscriptionIfExists(for: chain.chainId)
            clearRuntimeHandlingIfNeeded(for: chain.chainId)
        }

        logger?.debug("Sync mode \(chain.syncMode) applied to \(chain.name)")
    }

    private func setupRuntimeHandlingIfNeeded(for chain: ChainModel, connection: ChainConnection) {
        switch chain.syncMode {
        case .full:
            if chain.hasSubstrateRuntime {
                _ = runtimeProviderPool.setupRuntimeProviderIfNeeded(for: chain)

                runtimeSyncService.register(chain: chain, with: connection)

                logger?.debug("Subscribed runtime for: \(chain.name)")
            } else {
                clearRuntimeHandlingIfNeeded(for: chain.chainId)

                logger?.debug("No runtime for: \(chain.chainId)")
            }
        case .light, .disabled:
            clearRuntimeHandlingIfNeeded(for: chain.chainId)

            logger?.debug("No runtime \(chain.name) needed for sync mode \(chain.syncMode)")
        }
    }

    private func setupRuntimeVersionSubscriptionIfNeeded(for chain: ChainModel, connection: ChainConnection) {
        let optInfo = runtimeVersionSubscriptions[chain.chainId]

        guard optInfo == nil || optInfo?.syncMode != chain.syncMode else {
            return
        }

        optInfo?.subscription.unsubscribe()

        let subscription = specVersionSubscriptionFactory.createSubscription(
            for: chain,
            connection: connection
        )

        subscription.subscribe()

        runtimeVersionSubscriptions[chain.chainId] = .init(subscription: subscription, syncMode: chain.syncMode)
    }

    private func clearRuntimeHandlingIfNeeded(for chainId: ChainModel.Id) {
        runtimeProviderPool.destroyRuntimeProviderIfExists(for: chainId)
        runtimeSyncService.unregisterIfExists(chainId: chainId)
    }

    private func clearRuntimeSubscriptionIfExists(for chainId: ChainModel.Id) {
        if let info = runtimeVersionSubscriptions[chainId] {
            info.subscription.unsubscribe()
        }

        runtimeVersionSubscriptions[chainId] = nil
    }

    private func syncUpServices() {
        chainSyncService.syncUp()
        commonTypesSyncService.syncUp()
    }

    private func internalSwitchSync(mode: ChainSyncMode, chainId: ChainModel.Id) throws {
        guard let chain = availableChains[chainId], chain.syncMode != mode else {
            throw ChainRegistryError.noChain(chainId)
        }

        let newChain = chain.updatingSyncMode(for: mode)

        availableChains[chainId] = newChain
        try updateSyncMode(for: newChain)

        chainSyncService.updateLocal(chain: newChain)
    }
}

extension ChainRegistry: ChainRegistryProtocol {
    var availableChainIds: Set<ChainModel.Id>? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return Set(availableChains.keys)
    }

    func getChain(for chainId: ChainModel.Id) -> ChainModel? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return availableChains[chainId]
    }

    func getConnection(for chainId: ChainModel.Id) -> ChainConnection? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return connectionPool.getConnection(for: chainId)
    }

    func getOneShotConnection(for chainId: ChainModel.Id) -> JSONRPCEngine? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard let chain = availableChains[chainId] else {
            return nil
        }

        return connectionPool.getOneShotConnection(for: chain)
    }

    func getRuntimeProvider(for chainId: ChainModel.Id) -> RuntimeProviderProtocol? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if let runtimeProvider = runtimeProviderPool.getRuntimeProvider(for: chainId) {
            return runtimeProvider
        }

        guard let chain = availableChains[chainId], chain.isLightSyncMode else {
            return nil
        }

        // switch to full sync if one need runtime for some reason in light sync mode

        try? internalSwitchSync(mode: .full, chainId: chainId)

        return runtimeProviderPool.getRuntimeProvider(for: chainId)
    }

    func switchSync(mode: ChainSyncMode, chainId: ChainModel.Id) throws {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        try internalSwitchSync(mode: mode, chainId: chainId)
    }

    func chainsSubscribe(
        _ target: AnyObject,
        runningInQueue: DispatchQueue,
        filterStrategy: ChainFilterStrategy?,
        updateClosure: @escaping ([DataProviderChange<ChainModel>]) -> Void
    ) {
        mutex.lock()
        
        defer {
            mutex.unlock()
        }
        
        let closure: ([DataProviderChange<ChainModel>], [ChainModel.Id: ChainModel]) -> Void = { changes, currentChains in
            runningInQueue.async {
                let filtered = if let filterStrategy {
                    filterStrategy.filter(
                        changes,
                        using: currentChains
                    )
                } else {
                    changes
                }
                
                updateClosure(filtered)
            }
        }
        
        guard !chainsChangesObservers.contains(where: { $0.target === target }) else {
            return
        }
        
        chainsChangesObservers.append(
            ChainsObserver(
                target: target,
                updateClosure: closure
            )
        )
        
        guard !availableChains.isEmpty else {
            return
        }

        closure(
            availableChains.values.map { DataProviderChange<ChainModel>.insert(newItem: $0) },
            availableChains
        )
    }

    func chainsUnsubscribe(_ target: AnyObject) {
        chainProvider.removeObserver(target)
    }

    func subscribeChainState(_ subscriber: ConnectionStateSubscription, chainId: ChainModel.Id) {
        connectionPool.subscribe(subscriber, chainId: chainId)
    }

    func unsubscribeChainState(_ subscriber: ConnectionStateSubscription, chainId: ChainModel.Id) {
        connectionPool.unsubscribe(subscriber, chainId: chainId)
    }

    func syncUp() {
        syncUpServices()
    }
}

extension ChainRegistry {
    struct ChainsObserver {
        weak var target: AnyObject?
        var updateClosure: ([DataProviderChange<ChainModel>], [ChainModel.Id: ChainModel]) -> Void
    }
}
