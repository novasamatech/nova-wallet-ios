import Foundation
import RobinHood
import IrohaCrypto
import SubstrateSdk

final class StakingAccountSubscription: WebSocketSubscribing {
    struct Subscription {
        let handlers: [StorageChildSubscribing]
        let subscriptionId: UInt16
    }

    struct Request {
        let remotePath: StorageCodingPath
        let localPath: StorageCodingPath
        let accountId: AccountId

        init(
            remotePath: StorageCodingPath,
            localPath: StorageCodingPath,
            accountId: AccountId
        ) {
            self.remotePath = remotePath
            self.localPath = localPath
            self.accountId = accountId
        }

        init(storagePath: StorageCodingPath, accountId: AccountId) {
            remotePath = storagePath
            localPath = storagePath
            self.accountId = accountId
        }
    }

    let accountId: AccountId
    let chainId: ChainModel.Id
    let chainFormat: ChainFormat
    let chainRegistry: ChainRegistryProtocol
    let provider: StreamableProvider<StashItem>
    let childSubscriptionFactory: ChildSubscriptionFactoryProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol?

    private let mutex = NSLock()

    private var subscription: Subscription?

    init(
        accountId: AccountId,
        chainId: ChainModel.Id,
        chainFormat: ChainFormat,
        chainRegistry: ChainRegistryProtocol,
        provider: StreamableProvider<StashItem>,
        childSubscriptionFactory: ChildSubscriptionFactoryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol? = nil
    ) {
        self.accountId = accountId
        self.chainId = chainId
        self.chainFormat = chainFormat
        self.chainRegistry = chainRegistry
        self.provider = provider
        self.childSubscriptionFactory = childSubscriptionFactory
        self.operationQueue = operationQueue
        self.logger = logger

        subscribeLocal()
    }

    deinit {
        unsubscribeRemote()
    }

    private func subscribeLocal() {
        let changesClosure: ([DataProviderChange<StashItem>]) -> Void = { [weak self] changes in
            let stashItem: StashItem? = changes.reduce(nil) { _, item in
                switch item {
                case let .insert(newItem), let .update(newItem):
                    return newItem
                case .delete:
                    return nil
                }
            }

            self?.unsubscribeRemote()

            if let stashItem = stashItem {
                self?.subscribeRemote(for: stashItem)
            }
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.logger?.error("Did receive error: \(error)")
        }

        provider.addObserver(
            self,
            deliverOn: .global(qos: .userInitiated),
            executing: changesClosure,
            failing: failureClosure,
            options: StreamableProviderObserverOptions.substrateSource()
        )
    }

    private func unsubscribeRemote() {
        mutex.lock()

        if let subscriptionId = subscription?.subscriptionId {
            chainRegistry.getConnection(for: chainId)?.cancelForIdentifier(subscriptionId)
        }

        subscription = nil

        mutex.unlock()
    }

    private func createRequest(for stashItem: StashItem) throws -> [Request] {
        var requests: [Request] = []

        let stashId = try stashItem.stash.toAccountId(using: chainFormat)

        if stashId != accountId {
            requests.append(.init(storagePath: .controller, accountId: stashId))
            requests.append(.init(storagePath: .account, accountId: stashId))
        }

        let controllerId = try stashItem.controller.toAccountId(using: chainFormat)

        if controllerId != accountId {
            requests.append(.init(storagePath: .stakingLedger, accountId: controllerId))
            requests.append(.init(storagePath: .account, accountId: controllerId))
        }

        requests.append(.init(storagePath: .nominators, accountId: stashId))
        requests.append(.init(storagePath: .validatorPrefs, accountId: stashId))
        requests.append(.init(storagePath: .payee, accountId: stashId))

        BagList.possibleModuleNames.forEach { moduleName in
            let storagePath = BagList.bagListNode(for: moduleName)
            requests.append(
                .init(remotePath: storagePath, localPath: BagList.defaultBagListNodePath, accountId: stashId)
            )
        }

        return requests
    }

    private func subscribeRemote(for stashItem: StashItem) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        do {
            guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
                throw ChainRegistryError.runtimeMetadaUnavailable
            }

            let requests = try createRequest(for: stashItem)

            let localKeyFactory = LocalStorageKeyFactory()
            let localKeys = try requests.map {
                try localKeyFactory.createFromStoragePath($0.localPath, accountId: $0.accountId, chainId: chainId)
            }

            let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

            let storageKeyFactory = StorageKeyFactory()

            let codingOperations: [MapKeyEncodingOperation<Data>] = requests.map { request in
                MapKeyEncodingOperation(
                    path: request.remotePath,
                    storageKeyFactory: storageKeyFactory,
                    keyParams: [request.accountId]
                )
            }

            configureMapOperations(codingOperations, coderFactoryOperation: codingFactoryOperation)

            let mapOperation = ClosureOperation<[Data?]> { [weak self] in
                try codingOperations.map { operation in
                    do {
                        return try operation.extractNoCancellableResultData().first
                    } catch StorageKeyEncodingOperationError.invalidStoragePath {
                        // ignore keys if path missing in runtime
                        self?.logger?.warning("Subscription path missing in runtime: \(operation.path)")
                        return nil
                    }
                }
            }

            codingOperations.forEach { mapOperation.addDependency($0) }

            mapOperation.completionBlock = { [weak self] in
                do {
                    let remoteKeys = try mapOperation.extractNoCancellableResultData()
                    let keysList = zip(remoteKeys, localKeys).compactMap { remoteLocal in
                        if let remoteKey = remoteLocal.0 {
                            return SubscriptionStorageKeys(remote: remoteKey, local: remoteLocal.1)
                        } else {
                            return nil
                        }
                    }

                    self?.subscribeToRemote(with: keysList)
                } catch {
                    self?.logger?.error("Did receive error: \(error)")
                }
            }

            let operations = [codingFactoryOperation] + codingOperations + [mapOperation]

            operationQueue.addOperations(operations, waitUntilFinished: false)

        } catch {
            logger?.error("Did receive unexpected error \(error)")
        }
    }

    private func subscribeToRemote(
        with keysList: [SubscriptionStorageKeys]
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        do {
            guard let connection = chainRegistry.getConnection(for: chainId) else {
                throw ChainRegistryError.connectionUnavailable
            }

            let storageParams = keysList.map { $0.remote.toHex(includePrefix: true) }

            let updateClosure: (StorageSubscriptionUpdate) -> Void = { [weak self] update in
                self?.handleUpdate(update.params.result)
            }

            let failureClosure: (Error, Bool) -> Void = { [weak self] error, unsubscribed in
                self?.logger?.error("Did receive subscription error: \(error) \(unsubscribed)")
            }

            let subscriptionId = try connection.subscribe(
                RPCMethod.storageSubscribe,
                params: [storageParams],
                updateClosure: updateClosure,
                failureClosure: failureClosure
            )

            let handlers: [StorageChildSubscribing] = keysList.map { keys in
                childSubscriptionFactory.createEmptyHandlingSubscription(keys: keys)
            }

            subscription = Subscription(handlers: handlers, subscriptionId: subscriptionId)

        } catch {
            logger?.error("Can't subscribe to storage: \(error)")
        }
    }

    private func configureMapOperations(
        _ operations: [MapKeyEncodingOperation<Data>],
        coderFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) {
        operations.forEach { operation in
            operation.addDependency(coderFactoryOperation)

            operation.configurationBlock = {
                do {
                    guard let result = try coderFactoryOperation.extractResultData() else {
                        operation.cancel()
                        return
                    }

                    operation.codingFactory = result

                } catch {
                    operation.result = .failure(error)
                }
            }
        }
    }

    private func handleUpdate(_ update: StorageUpdate) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard let subscription = subscription else {
            logger?.warning("Staking update received but subscription is missing")
            return
        }

        let updateData = StorageUpdateData(update: update)

        subscription.handlers.forEach { applyHandler($0, for: updateData) }
    }

    private func applyHandler(_ handler: StorageChildSubscribing, for update: StorageUpdateData) {
        if let change = update.changes.first(where: { $0.key == handler.remoteStorageKey }) {
            handler.processUpdate(change.value, blockHash: update.blockHash)
        }
    }
}
