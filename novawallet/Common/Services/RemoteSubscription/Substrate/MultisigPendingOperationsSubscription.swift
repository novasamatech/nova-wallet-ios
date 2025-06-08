import Foundation
import Operation_iOS
import NovaCrypto
import SubstrateSdk

final class MultisigPendingOperationsSubscription: WebSocketSubscribing {
    let accountId: AccountId
    let chainId: ChainModel.Id
    let chainRegistry: ChainRegistryProtocol
    let delegatedAccountSyncService: DelegatedAccountSyncServiceProtocol
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
        delegatedAccountSyncService: DelegatedAccountSyncServiceProtocol,
        storageFacade: StorageFacadeProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue,
        logger: LoggerProtocol? = nil
    ) {
        self.accountId = accountId
        self.chainId = chainId
        self.chainRegistry = chainRegistry
        self.delegatedAccountSyncService = delegatedAccountSyncService
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
            Multisig.multisigList,
            accountId: accountId,
            chainId: chainId
        )

        let request = BatchStorageSubscriptionRequest(
            innerRequest: MapSubscriptionRequest(
                storagePath: Multisig.multisigList,
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
                delegatedAccountSyncService.syncUp(chainId: chainId, at: blockHash)
            }
        case let .failure(error):
            logger?.error(error.localizedDescription)
        }
    }
}
