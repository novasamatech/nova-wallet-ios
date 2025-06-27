import Foundation
import Operation_iOS
import SubstrateSdk

final class MultisigPendingOperationsSubscription: WebSocketSubscribing {
    let accountId: AccountId
    let chainId: ChainModel.Id
    let callHashes: Set<Substrate.CallHash>
    let chainRegistry: ChainRegistryProtocol
    let logger: LoggerProtocol?

    private let mutex = NSLock()
    private let operationQueue: OperationQueue
    private let workingQueue: DispatchQueue

    private var subscription: CallbackBatchStorageSubscription<SubscriptionResult>?
    private weak var subscriber: MultisigPendingOperationsSubscriber?

    init(
        accountId: AccountId,
        chainId: ChainModel.Id,
        callHashes: Set<Substrate.CallHash>,
        chainRegistry: ChainRegistryProtocol,
        subscriber: MultisigPendingOperationsSubscriber,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue,
        logger: LoggerProtocol? = nil
    ) {
        self.accountId = accountId
        self.chainId = chainId
        self.callHashes = callHashes
        self.chainRegistry = chainRegistry
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
        callHashes: Set<Substrate.CallHash>
    ) throws {
        let connection = try chainRegistry.getConnectionOrError(for: chainId)
        let runtimeService = try chainRegistry.getRuntimeProviderOrError(for: chainId)

        let requests = callHashes.map { callHash in
            BatchStorageSubscriptionRequest(
                innerRequest: DoubleMapSubscriptionRequest(
                    storagePath: MultisigPallet.multisigListStoragePath,
                    localKey: "",
                    keyParamClosure: {
                        (
                            BytesCodable(wrappedValue: accountId),
                            BytesCodable(wrappedValue: callHash)
                        )
                    }
                ),
                mappingKey: SubscriptionResult.Key.pendingOperation(with: callHash)
            )
        }
        
        unsubscribeRemote()

        subscription = CallbackBatchStorageSubscription(
            requests: requests,
            connection: connection,
            runtimeService: runtimeService,
            repository: nil,
            operationQueue: operationQueue,
            callbackQueue: workingQueue
        ) { [weak self] result in
            self?.handleSubscription(result, callHashes: callHashes)
        }
        subscription?.subscribe()
    }

    func handleSubscription(
        _ result: Result<SubscriptionResult, Error>,
        callHashes: Set<Substrate.CallHash>
    ) {
        switch result {
        case let .success(state):
            callHashes
                .map { callHash in
                    let key = SubscriptionResult.Key.pendingOperation(with: callHash)
                    let json = state.values[key]

                    let definition = try? json?.map(
                        to: MultisigPallet.MultisigDefinition.self,
                        with: state.context
                    )

                    return (callHash, definition)
                }
                .forEach {
                    subscriber?.didReceiveUpdate(
                        callHash: $0.0,
                        multisigDefinition: $0.1
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
        static func pendingOperation(with callHash: Substrate.CallHash) -> String {
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
