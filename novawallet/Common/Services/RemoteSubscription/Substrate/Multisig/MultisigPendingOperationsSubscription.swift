import Foundation
import Operation_iOS
import SubstrateSdk

typealias CallHash = Data

final class MultisigPendingOperationsSubscription: WebSocketSubscribing {
    let accountId: AccountId
    let chainId: ChainModel.Id
    let callHashes: Set<CallHash>
    let chainRegistry: ChainRegistryProtocol
    let storageFacade: StorageFacadeProtocol
    let logger: LoggerProtocol?

    private let mutex = NSLock()
    private let operationQueue: OperationQueue
    private let workingQueue: DispatchQueue

    private var subscription: CallbackBatchStorageSubscription<SubscriptionResult>?
    private weak var subscriber: MultisigPendingOperationsSubscriber?

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
        storageFacade: StorageFacadeProtocol,
        subscriber: MultisigPendingOperationsSubscriber,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue,
        logger: LoggerProtocol? = nil
    ) {
        self.accountId = accountId
        self.chainId = chainId
        self.callHashes = callHashes
        self.chainRegistry = chainRegistry
        self.storageFacade = storageFacade
        self.subscriber = subscriber
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue
        self.logger = logger

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

        let requests = callHashes.map { callHash in
            BatchStorageSubscriptionRequest(
                innerRequest: DoubleMapSubscriptionRequest(
                    storagePath: Multisig.multisigList,
                    localKey: localKey
                ) {
                    (
                        BytesCodable(wrappedValue: accountId),
                        BytesCodable(wrappedValue: callHash)
                    )
                },
                mappingKey: SubscriptionResult.Key.pendingOperation(with: callHash)
            )
        }

        subscription = CallbackBatchStorageSubscription(
            requests: requests,
            connection: connection,
            runtimeService: runtimeService,
            repository: repository,
            operationQueue: operationQueue,
            callbackQueue: workingQueue
        ) { [weak self] result in
            self?.mutex.lock()

            self?.handleSubscription(result, callHashes: callHashes)

            self?.mutex.unlock()
        }
    }

    func handleSubscription(
        _ result: Result<SubscriptionResult, Error>,
        callHashes: Set<CallHash>
    ) {
        switch result {
        case let .success(state):
            callHashes
                .reduce(into: [:]) { acc, callHash in
                    let key = SubscriptionResult.Key.pendingOperation(with: callHash)
                    let json = state.values[key]

                    guard let definition = try? json?.map(
                        to: Multisig.MultisigDefinition.self,
                        with: state.context
                    ) else { return }

                    acc[callHash] = definition
                }
                .forEach {
                    subscriber?.didReceiveUpdate(
                        callHash: $0.key,
                        multisigDefinition: $0.value
                    )
                }
        case let .failure(error):
            logger?.error(error.localizedDescription)
        }
    }
}

// MARK: - SubscriptionResult

private struct SubscriptionResult: BatchStorageSubscriptionResult {
    enum Key {
        static func pendingOperation(with callHash: CallHash) -> String {
            "pendingOperation:" + callHash.toHexString()
        }
    }

    let context: [CodingUserInfoKey: Any]?
    let values: [String: JSON]

    init(
        values: [BatchStorageSubscriptionResultValue],
        blockHashJson _: JSON,
        context: [CodingUserInfoKey: Any]?
    ) throws {
        self.context = context
        self.values = values.reduce(into: [String: JSON]()) {
            if let mappingKey = $1.mappingKey {
                $0[mappingKey] = $1.value
            }
        }
    }
}
