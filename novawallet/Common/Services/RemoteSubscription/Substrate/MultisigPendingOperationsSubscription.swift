import Foundation
import Operation_iOS
import NovaCrypto
import SubstrateSdk

typealias CallHash = Data

final class MultisigPendingOperationsSubscription: WebSocketSubscribing {
    let accountId: AccountId
    let chainId: ChainModel.Id
    let callHashes: Set<CallHash>
    let chainRegistry: ChainRegistryProtocol
    let delegatedAccountSyncService: DelegatedAccountSyncServiceProtocol
    let storageFacade: StorageFacadeProtocol
    let logger: LoggerProtocol?

    private let mutex = NSLock()
    private let operationQueue: OperationQueue
    private let workingQueue: DispatchQueue
    private var subscription: CallbackStorageSubscription<[CallHash: Multisig.MultisigDefinition]>?

    private lazy var repository: AnyDataProviderRepository<ChainStorageItem> = {
        let coreDataRepository: CoreDataRepository<ChainStorageItem, CDChainStorageItem> =
            storageFacade.createRepository()
        return AnyDataProviderRepository(coreDataRepository)
    }()

    init(
        accountId: AccountId,
        chainId: ChainModel.Id,
        callHashes: Set<CallHash>,
        chainRegistry: ChainRegistryProtocol,
        delegatedAccountSyncService: DelegatedAccountSyncServiceProtocol,
        storageFacade: StorageFacadeProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue,
        logger: LoggerProtocol? = nil
    ) {
        self.accountId = accountId
        self.chainId = chainId
        self.callHashes = callHashes
        self.chainRegistry = chainRegistry
        self.delegatedAccountSyncService = delegatedAccountSyncService
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue
        self.logger = logger
        self.storageFacade = storageFacade

        do {
            try subscribeRemote(
                for: accountId,
                callHashes: callHashes
            )
        } catch {
            logger?.error(error.localizedDescription)
        }
    }

    deinit {
        unsubscribeRemote()
    }
}

// MARK: - Private

private extension MultisigPendingOperationsSubscription {
    func unsubscribeRemote() {
        subscription?.unsubscribe()
        subscription = nil
    }

    func subscribeRemote(
        for accountId: AccountId,
        callHashes: Set<CallHash>
    ) throws {
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

        let request = DoubleMapSubscriptionRequest(
            storagePath: Multisig.multisigList,
            localKey: localKey
        ) {
            (
                BytesCodable(wrappedValue: accountId),
                callHashes.map { BytesCodable(wrappedValue: $0) }
            )
        }

        subscription = CallbackStorageSubscription(
            request: request,
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
    }

    func handleSubscription(_ result: Result<[CallHash: Multisig.MultisigDefinition]?, Error>) {
        switch result {
        case let .success(state):
            guard let state else { return }
            logger?.debug(state.debugDescription)
        case let .failure(error):
            logger?.error(error.localizedDescription)
        }
    }
}
