import Foundation
import Operation_iOS
import SubstrateSdk

typealias RemoteSubscriptionClosure = (Result<Void, Error>) -> Void

enum RemoteSubscriptionServiceError: Error {
    case remoteKeysNotMatchLocal
}

class RemoteSubscriptionService {
    struct Callback {
        let queue: DispatchQueue
        let closure: RemoteSubscriptionClosure
    }

    class Active {
        var subscriptionIds: Set<UUID>
        let container: StorageSubscriptionContainer

        init(subscriptionIds: Set<UUID>, container: StorageSubscriptionContainer) {
            self.subscriptionIds = subscriptionIds
            self.container = container
        }
    }

    class Pending {
        var subscriptionIds: Set<UUID>
        let wrapper: CompoundOperationWrapper<StorageSubscriptionContainer>
        var callbacks: [UUID: Callback]

        init(
            subscriptionIds: Set<UUID>,
            wrapper: CompoundOperationWrapper<StorageSubscriptionContainer>,
            callbacks: [UUID: Callback]
        ) {
            self.subscriptionIds = subscriptionIds
            self.wrapper = wrapper
            self.callbacks = callbacks
        }
    }

    let chainRegistry: ChainRegistryProtocol
    let repository: AnyDataProviderRepository<ChainStorageItem>
    let syncOperationManager: OperationManagerProtocol
    let repositoryOperationManager: OperationManagerProtocol
    let logger: LoggerProtocol

    private var activeSubscriptions: [String: Active] = [:]
    private var pendingSubscriptions: [String: Pending] = [:]

    private let mutex = NSLock()

    private lazy var localStorageKeyFactory = LocalStorageKeyFactory()
    private lazy var remoteStorageKeyFactory = StorageKeyFactory()
    private lazy var defaultSubscriptionHandlingFactory = DefaultRemoteSubscriptionHandlingFactory()

    init(
        chainRegistry: ChainRegistryProtocol,
        repository: AnyDataProviderRepository<ChainStorageItem>,
        syncOperationManager: OperationManagerProtocol,
        repositoryOperationManager: OperationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.repository = repository
        self.syncOperationManager = syncOperationManager
        self.repositoryOperationManager = repositoryOperationManager
        self.logger = logger
    }

    func attachToSubscription(
        with requests: [SubscriptionRequestProtocol],
        chainId: ChainModel.Id,
        cacheKey: String,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?,
        subscriptionHandlingFactory: RemoteSubscriptionHandlingFactoryProtocol? = nil
    ) -> UUID {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        let subscriptionId = UUID()

        if let active = activeSubscriptions[cacheKey] {
            active.subscriptionIds.insert(subscriptionId)

            callbackClosureIfProvided(closure, queue: queue, result: .success(()))

            return subscriptionId
        }

        if let pending = pendingSubscriptions[cacheKey] {
            pending.subscriptionIds.insert(subscriptionId)

            if let closure = closure {
                pending.callbacks[subscriptionId] = Callback(queue: queue ?? .main, closure: closure)
            }

            return subscriptionId
        }

        let wrapper = subscriptionOperation(
            using: requests,
            chainId: chainId,
            cacheKey: cacheKey,
            subscriptionHandlingFactory: subscriptionHandlingFactory ?? defaultSubscriptionHandlingFactory,
            logger: logger
        )

        let pending = Pending(
            subscriptionIds: [subscriptionId],
            wrapper: wrapper,
            callbacks: [:]
        )

        if let closure = closure {
            pending.callbacks[subscriptionId] = Callback(queue: queue ?? .main, closure: closure)
        }

        pendingSubscriptions[cacheKey] = pending

        syncOperationManager.enqueue(operations: wrapper.allOperations, in: .transient)

        logger.debug("Operations enqued for subscription: \(chainId)")

        return subscriptionId
    }

    func detachFromSubscription(
        _ cacheKey: String,
        subscriptionId: UUID,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if let active = activeSubscriptions[cacheKey] {
            active.subscriptionIds.remove(subscriptionId)

            if active.subscriptionIds.isEmpty {
                activeSubscriptions[cacheKey] = nil
            }

            callbackClosureIfProvided(closure, queue: queue ?? .main, result: .success(()))
        } else if let pending = pendingSubscriptions[cacheKey] {
            pending.subscriptionIds.remove(subscriptionId)
            pending.callbacks[subscriptionId] = nil

            if pending.subscriptionIds.isEmpty {
                pendingSubscriptions[cacheKey] = nil
                pending.wrapper.cancel()
            }

            callbackClosureIfProvided(closure, queue: queue ?? .main, result: .success(()))
        } else {
            callbackClosureIfProvided(closure, queue: queue ?? .main, result: .success(()))
        }
    }

    private func subscriptionOperation(
        using requests: [SubscriptionRequestProtocol],
        chainId: ChainModel.Id,
        cacheKey: String,
        subscriptionHandlingFactory: RemoteSubscriptionHandlingFactoryProtocol,
        logger: LoggerProtocol
    ) -> CompoundOperationWrapper<StorageSubscriptionContainer> {
        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainId) else {
            return CompoundOperationWrapper.createWithError(
                ChainRegistryError.runtimeMetadaUnavailable
            )
        }

        let coderFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let keyEncodingWrappers: [CompoundOperationWrapper<Data>] = requests.map { request in
            let wrapper = request.createKeyEncodingWrapper(using: remoteStorageKeyFactory) {
                try coderFactoryOperation.extractNoCancellableResultData()
            }

            wrapper.addDependency(operations: [coderFactoryOperation])

            return wrapper
        }

        let containerOperation = ClosureOperation<StorageSubscriptionContainer> {
            guard keyEncodingWrappers.count == requests.count else {
                throw RemoteSubscriptionServiceError.remoteKeysNotMatchLocal
            }

            let remoteLocalKeys: [SubscriptionStorageKeys] = zip(keyEncodingWrappers, requests)
                .compactMap { encodingWrapper, request in
                    do {
                        let remoteKey = try encodingWrapper.targetOperation.extractNoCancellableResultData()
                        return SubscriptionStorageKeys(remote: remoteKey, local: request.localKey)
                    } catch StorageKeyEncodingOperationError.invalidStoragePath {
                        // ignore keys if path missing in runtime
                        logger.warning("Subscription path missing in runtime: \(request.storagePath)")
                        return nil
                    } catch {
                        // ignore keys if subscription broken
                        logger.error("Subscription failed in \(chainId): \(request.storagePath)")
                        return nil
                    }
                }

            let container = try self.createContainer(
                for: chainId,
                remoteLocalKeys: remoteLocalKeys,
                subscriptionHandlingFactory: subscriptionHandlingFactory
            )

            return container
        }

        keyEncodingWrappers.forEach { containerOperation.addDependency($0.targetOperation) }

        containerOperation.completionBlock = {
            DispatchQueue.global(qos: .default).async {
                self.mutex.lock()

                defer {
                    self.mutex.unlock()
                }

                self.handleSubscriptionInitResult(containerOperation.result, cacheKey: cacheKey)
            }
        }

        let allWrapperOperations = keyEncodingWrappers.flatMap(\.allOperations)

        return CompoundOperationWrapper(
            targetOperation: containerOperation,
            dependencies: [coderFactoryOperation] + allWrapperOperations
        )
    }

    private func createContainer(
        for chainId: ChainModel.Id,
        remoteLocalKeys: [SubscriptionStorageKeys],
        subscriptionHandlingFactory: RemoteSubscriptionHandlingFactoryProtocol
    ) throws -> StorageSubscriptionContainer {
        guard let connection = chainRegistry.getConnection(for: chainId) else {
            throw ChainRegistryError.connectionUnavailable
        }

        let subscriptions = remoteLocalKeys.map { keysPair in
            subscriptionHandlingFactory.createHandler(
                remoteStorageKey: keysPair.remote,
                localStorageKey: keysPair.local,
                storage: repository,
                operationManager: repositoryOperationManager,
                logger: logger
            )
        }

        let container = StorageSubscriptionContainer(
            engine: connection,
            children: subscriptions,
            logger: logger
        )

        return container
    }

    func handleSubscriptionInitResult(_ result: Result<StorageSubscriptionContainer, Error>?, cacheKey: String) {
        guard let pending = pendingSubscriptions[cacheKey] else {
            return
        }

        logger.debug("Complete subscription with key: \(cacheKey)")

        switch result {
        case let .success(container):
            if !pending.subscriptionIds.isEmpty {
                let active = Active(subscriptionIds: pending.subscriptionIds, container: container)
                activeSubscriptions[cacheKey] = active
            }

            clearPendingWithResult(.success(()), for: cacheKey)
        case let .failure(error):
            clearPendingWithResult(.failure(error), for: cacheKey)
        case .none:
            clearPendingWithResult(.failure(BaseOperationError.parentOperationCancelled), for: cacheKey)
        }
    }

    private func clearPendingWithResult(_ result: Result<Void, Error>, for cacheKey: String) {
        guard let pendings = pendingSubscriptions[cacheKey] else {
            return
        }

        pendingSubscriptions[cacheKey] = nil

        for pending in pendings.callbacks.values {
            pending.queue.async {
                pending.closure(result)
            }
        }
    }
}
