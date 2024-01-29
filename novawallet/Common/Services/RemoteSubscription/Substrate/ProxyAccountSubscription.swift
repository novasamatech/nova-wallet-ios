import Foundation
import RobinHood
import IrohaCrypto
import SubstrateSdk

final class ProxyAccountSubscription: WebSocketSubscribing {
    let accountId: AccountId
    let chainId: ChainModel.Id
    let chainRegistry: ChainRegistryProtocol
    let proxySyncService: ProxySyncServiceProtocol
    let logger: LoggerProtocol?
    let childSubscriptionFactory: ChildSubscriptionFactoryProtocol

    private let mutex = NSLock()
    private let operationQueue: OperationQueue
    private var subscriptionId: UInt16?
    private var remoteStorageKey: Data?
    private var storageSubscriptionHandler: StorageChildSubscribing?

    init(
        accountId: AccountId,
        chainId: ChainModel.Id,
        chainRegistry: ChainRegistryProtocol,
        proxySyncService: ProxySyncServiceProtocol,
        childSubscriptionFactory: ChildSubscriptionFactoryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol? = nil
    ) {
        self.accountId = accountId
        self.chainId = chainId
        self.chainRegistry = chainRegistry
        self.proxySyncService = proxySyncService
        self.childSubscriptionFactory = childSubscriptionFactory
        self.operationQueue = operationQueue
        self.logger = logger

        subscribeRemote(for: accountId)
    }

    deinit {
        unsubscribeRemote()
    }

    private func unsubscribeRemote() {
        mutex.lock()

        if let subscriptionId = subscriptionId {
            chainRegistry.getConnection(for: chainId)?.cancelForIdentifier(subscriptionId)
        }

        subscriptionId = nil
        remoteStorageKey = nil
        storageSubscriptionHandler = nil

        mutex.unlock()
    }

    private func subscribeRemote(for accountId: AccountId) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        do {
            guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
                throw ChainRegistryError.runtimeMetadaUnavailable
            }
            let path = Proxy.proxyList
            let localKey = try LocalStorageKeyFactory().createFromStoragePath(
                path,
                accountId: accountId,
                chainId: chainId
            )

            let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

            let storageKeyFactory = StorageKeyFactory()

            let codingOperation = MapKeyEncodingOperation(
                path: path,
                storageKeyFactory: storageKeyFactory,
                keyParams: [accountId]
            )

            codingOperation.addDependency(codingFactoryOperation)

            codingOperation.configurationBlock = {
                do {
                    guard let result = try codingFactoryOperation.extractResultData() else {
                        codingOperation.cancel()
                        return
                    }

                    codingOperation.codingFactory = result

                } catch {
                    codingOperation.result = .failure(error)
                }
            }

            let mapOperation = ClosureOperation<Data?> { [weak self] in
                do {
                    return try codingOperation.extractNoCancellableResultData().first
                } catch StorageKeyEncodingOperationError.invalidStoragePath {
                    self?.logger?.warning("Subscription path missing in runtime: \(codingOperation.path)")
                    return nil
                }
            }

            mapOperation.addDependency(codingOperation)

            mapOperation.completionBlock = { [weak self] in
                do {
                    if let remoteKey = try mapOperation.extractNoCancellableResultData() {
                        let key = SubscriptionStorageKeys(remote: remoteKey, local: localKey)
                        self?.subscribeToRemote(with: key)
                    }
                } catch {
                    self?.logger?.error("Did receive error: \(error)")
                }
            }

            let operations = [codingFactoryOperation, codingOperation, mapOperation]

            operationQueue.addOperations(operations, waitUntilFinished: false)

        } catch {
            logger?.error("Did receive unexpected error \(error)")
        }
    }

    private func subscribeToRemote(
        with keyPair: SubscriptionStorageKeys
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        do {
            guard let connection = chainRegistry.getConnection(for: chainId) else {
                throw ChainRegistryError.connectionUnavailable
            }

            let storageParam = keyPair.remote.toHex(includePrefix: true)

            let updateClosure: (StorageSubscriptionUpdate) -> Void = { [weak self] update in
                self?.handleUpdate(update.params.result)
            }

            let failureClosure: (Error, Bool) -> Void = { [weak self] error, unsubscribed in
                self?.logger?.error("Did receive subscription error: \(error) \(unsubscribed)")
            }

            let subscriptionId = try connection.subscribe(
                RPCMethod.storageSubscribe,
                params: [[storageParam]],
                updateClosure: updateClosure,
                failureClosure: failureClosure
            )

            self.subscriptionId = subscriptionId
            remoteStorageKey = keyPair.remote
            storageSubscriptionHandler = childSubscriptionFactory.createEmptyHandlingSubscription(keys: keyPair)
        } catch {
            logger?.error("Can't subscribe to storage: \(error)")
        }
    }

    private func handleUpdate(_ update: StorageUpdate) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard let subscriptionId = subscriptionId else {
            logger?.warning("Staking update received but subscription is missing")
            return
        }

        guard let remoteStorageKey = remoteStorageKey else {
            logger?.warning("Remote storage key is missing")
            return
        }

        let storageUpdate = StorageUpdateData(update: update)

        if let change = storageUpdate.changes.first(where: { $0.key == remoteStorageKey }) {
            let blockHashData = update.blockHash.map { try? Data(hexString: $0) } ?? nil
            storageSubscriptionHandler?.processUpdate(change.value, blockHash: blockHashData)

            if let blockHashData = blockHashData {
                proxySyncService.syncUp(chainId: chainId, blockHash: blockHashData)
            }
        }
    }
}
