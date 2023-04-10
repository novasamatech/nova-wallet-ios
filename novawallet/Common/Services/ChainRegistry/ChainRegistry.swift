import Foundation
import RobinHood
import SubstrateSdk

protocol ChainRegistryProtocol: AnyObject {
    var availableChainIds: Set<ChainModel.Id>? { get }

    func getChain(for chainId: ChainModel.Id) -> ChainModel?
    func getConnection(for chainId: ChainModel.Id) -> ChainConnection?
    func getOneShotConnection(for chainId: ChainModel.Id) -> JSONRPCEngine?
    func getRuntimeProvider(for chainId: ChainModel.Id) -> RuntimeProviderProtocol?

    func chainsSubscribe(
        _ target: AnyObject,
        runningInQueue: DispatchQueue,
        updateClosure: @escaping ([DataProviderChange<ChainModel>]) -> Void
    )

    func chainsUnsubscribe(_ target: AnyObject)

    func subscribeChainState(_ subscriber: ConnectionStateSubscription, chainId: ChainModel.Id)
    func unsubscribeChainState(_ subscriber: ConnectionStateSubscription, chainId: ChainModel.Id)

    func syncUp()
}

final class ChainRegistry {
    let runtimeProviderPool: RuntimeProviderPoolProtocol
    let connectionPool: ConnectionPoolProtocol
    let chainSyncService: ChainSyncServiceProtocol
    let runtimeSyncService: RuntimeSyncServiceProtocol
    let commonTypesSyncService: CommonTypesSyncServiceProtocol
    let chainProvider: StreamableProvider<ChainModel>
    let specVersionSubscriptionFactory: SpecVersionSubscriptionFactoryProtocol
    let logger: LoggerProtocol?

    private(set) var runtimeVersionSubscriptions: [ChainModel.Id: SpecVersionSubscriptionProtocol] = [:]
    private var availableChains = Set<ChainModel>()

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

        changes.forEach { change in
            do {
                switch change {
                case let .insert(newChain):
                    availableChains.insert(newChain)

                    let connection = try connectionPool.setupConnection(for: newChain)

                    setupRuntimeHandlingIfNeeded(for: newChain, connection: connection)
                    setupRuntimeVersionSubscriptionIfNeeded(for: newChain, connection: connection)
                case let .update(updatedChain):
                    if let currentChain = availableChains.firstIndex(where: { $0.chainId == updatedChain.chainId }) {
                        availableChains.remove(at: currentChain)
                    }

                    availableChains.insert(updatedChain)

                    let connection = try connectionPool.setupConnection(for: updatedChain)

                    setupRuntimeHandlingIfNeeded(for: updatedChain, connection: connection)
                    setupRuntimeVersionSubscriptionIfNeeded(for: updatedChain, connection: connection)
                case let .delete(chainId):
                    if let currentChain = availableChains.firstIndex(where: { $0.chainId == chainId }) {
                        availableChains.remove(at: currentChain)
                    }

                    clearRuntimeSubscriptionIfExists(for: chainId)
                    clearRuntimeHandlingIfNeeded(for: chainId)

                    logger?.debug("Cleared runtime for: \(chainId)")
                }
            } catch {
                logger?.error("Unexpected error on handling chains update: \(error)")
            }
        }
    }

    private func setupRuntimeHandlingIfNeeded(for chain: ChainModel, connection: ChainConnection) {
        if chain.hasSubstrateRuntime {
            _ = runtimeProviderPool.setupRuntimeProviderIfNeeded(for: chain)

            runtimeSyncService.register(chain: chain, with: connection)

            logger?.debug("Subscribed runtime for: \(chain.name)")
        } else {
            clearRuntimeHandlingIfNeeded(for: chain.chainId)

            logger?.debug("No runtime for: \(chain.chainId)")
        }
    }

    private func setupRuntimeVersionSubscriptionIfNeeded(for chain: ChainModel, connection: ChainConnection) {
        guard runtimeVersionSubscriptions[chain.chainId] == nil else {
            return
        }

        let subscription = specVersionSubscriptionFactory.createSubscription(
            for: chain,
            connection: connection
        )

        subscription.subscribe()

        runtimeVersionSubscriptions[chain.chainId] = subscription
    }

    private func clearRuntimeHandlingIfNeeded(for chainId: ChainModel.Id) {
        runtimeProviderPool.destroyRuntimeProviderIfExists(for: chainId)
        runtimeSyncService.unregisterIfExists(chainId: chainId)
    }

    private func clearRuntimeSubscriptionIfExists(for chainId: ChainModel.Id) {
        if let subscription = runtimeVersionSubscriptions[chainId] {
            subscription.unsubscribe()
        }

        runtimeVersionSubscriptions[chainId] = nil
    }

    private func syncUpServices() {
        chainSyncService.syncUp()
        commonTypesSyncService.syncUp()
    }
}

extension ChainRegistry: ChainRegistryProtocol {
    var availableChainIds: Set<ChainModel.Id>? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return Set(runtimeVersionSubscriptions.keys)
    }

    func getChain(for chainId: ChainModel.Id) -> ChainModel? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return availableChains.first(where: { $0.chainId == chainId })
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

        guard let chain = availableChains.first(where: { $0.chainId == chainId }) else {
            return nil
        }

        return connectionPool.getOneShotConnection(for: chain)
    }

    func getRuntimeProvider(for chainId: ChainModel.Id) -> RuntimeProviderProtocol? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return runtimeProviderPool.getRuntimeProvider(for: chainId)
    }

    func chainsSubscribe(
        _ target: AnyObject,
        runningInQueue: DispatchQueue,
        updateClosure: @escaping ([DataProviderChange<ChainModel>]) -> Void
    ) {
        let updateClosure: ([DataProviderChange<ChainModel>]) -> Void = { changes in
            runningInQueue.async {
                updateClosure(changes)
            }
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
            target,
            deliverOn: DispatchQueue.global(qos: .userInitiated),
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }

    func chainsUnsubscribe(_ target: AnyObject) {
        chainProvider.removeObserver(target)
    }

    func subscribeChainState(_ subscriber: ConnectionStateSubscription, chainId: ChainModel.Id) {
        connectionPool.subscribe(subscriber, chainId: chainId)
    }

    func unsubscribeChainState(_ subscriber: ConnectionStateSubscription, chainId: ChainModel.Id) {
        connectionPool.subscribe(subscriber, chainId: chainId)
    }

    func syncUp() {
        syncUpServices()
    }
}
