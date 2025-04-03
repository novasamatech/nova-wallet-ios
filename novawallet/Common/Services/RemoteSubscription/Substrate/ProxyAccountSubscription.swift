import Foundation
import Operation_iOS
import NovaCrypto
import SubstrateSdk

final class ProxyAccountSubscription: WebSocketSubscribing {
    let accountId: AccountId
    let chainId: ChainModel.Id
    let chainRegistry: ChainRegistryProtocol
    let proxySyncService: ProxySyncServiceProtocol
    let storageFacade: StorageFacadeProtocol
    let logger: LoggerProtocol?

    private let mutex = NSLock()
    private let operationQueue: OperationQueue
    private let workingQueue: DispatchQueue
    private var subscription: CallbackBatchStorageSubscription<BatchSubscriptionHandler>?
    private var storageSubscriptionHandler: StorageChildSubscribing?

    private lazy var repository: AnyDataProviderRepository<ChainStorageItem> = {
        let coreDataRepository: CoreDataRepository<ChainStorageItem, CDChainStorageItem> =
            storageFacade.createRepository()
        return AnyDataProviderRepository(coreDataRepository)
    }()

    init(
        accountId: AccountId,
        chainId: ChainModel.Id,
        chainRegistry: ChainRegistryProtocol,
        proxySyncService: ProxySyncServiceProtocol,
        storageFacade: StorageFacadeProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue,
        logger: LoggerProtocol? = nil
    ) {
        self.accountId = accountId
        self.chainId = chainId
        self.chainRegistry = chainRegistry
        self.proxySyncService = proxySyncService
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue
        self.logger = logger
        self.storageFacade = storageFacade

        do {
            try subscribeRemote(for: accountId)
        } catch {
            logger?.error(error.localizedDescription)
        }
    }

    deinit {
        unsubscribeRemote()
    }

    private func unsubscribeRemote() {
        subscription?.unsubscribe()
        subscription = nil
    }

    private func subscribeRemote(for accountId: AccountId) throws {
        guard let connection = chainRegistry.getConnection(for: chainId) else {
            throw ChainRegistryError.connectionUnavailable
        }
        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            throw ChainRegistryError.runtimeMetadaUnavailable
        }

        let localKey = try LocalStorageKeyFactory().createFromStoragePath(
            Proxy.proxyList,
            accountId: accountId,
            chainId: chainId
        )

        let request = BatchStorageSubscriptionRequest(
            innerRequest: MapSubscriptionRequest(
                storagePath: Proxy.proxyList,
                localKey: localKey
            ) {
                BytesCodable(wrappedValue: accountId)
            },
            mappingKey: nil
        )

        subscription = CallbackBatchStorageSubscription(
            requests: [request],
            connection: connection,
            runtimeService: runtimeService,
            repository: repository,
            operationQueue: operationQueue,
            callbackQueue: workingQueue
        ) { [weak self] result in
            self?.mutex.lock()

            self?.handleSubscription(result)

            self?.mutex.unlock()
        }

        subscription?.subscribe()
    }

    private func handleSubscription(_ result: Result<BatchSubscriptionHandler, Error>) {
        switch result {
        case let .success(handler):
            if let blockHash = handler.blockHash {
                proxySyncService.syncUp(chainId: chainId, blockHash: blockHash)
            }
        case let .failure(error):
            logger?.error(error.localizedDescription)
        }
    }
}
