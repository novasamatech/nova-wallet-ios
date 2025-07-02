import Foundation
import Operation_iOS
import SubstrateSdk

final class MultisigPendingOperationsSubscription: WebSocketSubscribing {
    let accountId: AccountId
    let chainId: ChainModel.Id
    let callHashes: Set<Substrate.CallHash>
    let chainRegistry: ChainRegistryProtocol
    let logger: LoggerProtocol

    private let operationQueue: OperationQueue
    private let workingQueue: DispatchQueue

    private var subscription: CallbackBatchStorageSubscription<SubscriptionResult>?
    private weak var subscriber: MultisigPendingOperationsSubscriber?

    private var pendingCallStore: CancellableCallStore?
    private let blockNumberOperationFactory: BlockNumberOperationFactoryProtocol
    private let blockTimeOperationFactory: BlockTimeOperationFactoryProtocol
    private let runtimeProvider: RuntimeProviderProtocol

    init?(
        accountId: AccountId,
        chainId: ChainModel.Id,
        callHashes: Set<Substrate.CallHash>,
        chainRegistry: ChainRegistryProtocol,
        subscriber: MultisigPendingOperationsSubscriber,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue,
        logger: LoggerProtocol
    ) {
        self.accountId = accountId
        self.chainId = chainId
        self.callHashes = callHashes
        self.chainRegistry = chainRegistry
        self.subscriber = subscriber
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue
        self.logger = logger

        blockNumberOperationFactory = BlockNumberOperationFactory(
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )

        do {
            let chain = try chainRegistry.getChainOrError(for: chainId)

            runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chainId)
            blockTimeOperationFactory = BlockTimeOperationFactory(chain: chain)

            try subscribeRemote(
                for: accountId,
                callHashes: callHashes
            )
        } catch {
            logger.error(error.localizedDescription)
            return nil
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
            fetchTimestampParamsAndNotify(
                state: state,
                callHashes: callHashes
            )
        case let .failure(error):
            logger.error(error.localizedDescription)
        }
    }

    func fetchTimestampParamsAndNotify(
        state: SubscriptionResult,
        callHashes: Set<Substrate.CallHash>
    ) {
        let blockNumberWrapper = blockNumberOperationFactory.createWrapper(
            for: chainId,
            blockHash: state.blockHash
        )

        let blockTimeWrapper = blockTimeOperationFactory.createExpectedBlockTimeWrapper(from: runtimeProvider)

        let updatesOperation = ClosureOperation<[(Substrate.CallHash, MultisigDefinitionWithTime?)]> {
            let blockTime = try blockTimeWrapper.targetOperation.extractNoCancellableResultData()
            let blockNumber = try blockNumberWrapper.targetOperation.extractNoCancellableResultData()

            return self.calculateChanges(
                state: state,
                callHashes: callHashes,
                blockNumber: blockNumber,
                blockTime: blockTime
            )
        }

        updatesOperation.addDependency(blockTimeWrapper.targetOperation)
        updatesOperation.addDependency(blockNumberWrapper.targetOperation)

        let wrapper = blockTimeWrapper.insertingHead(
            operations: blockTimeWrapper.allOperations
        ).insertingTail(operation: updatesOperation)

        pendingCallStore?.addDependency(to: wrapper)

        let newCallStore = CancellableCallStore()
        pendingCallStore = newCallStore

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: newCallStore,
            runningCallbackIn: workingQueue
        ) { [weak self] result in
            switch result {
            case let .success(changes):
                changes.forEach { change in
                    self?.subscriber?.didReceiveUpdate(
                        callHash: change.0,
                        multisigDefinition: change.1
                    )
                }
            case let .failure(error):
                self?.logger.error("Can't process changes: \(error)")
            }
        }
    }

    func calculateChanges(
        state: SubscriptionResult,
        callHashes: Set<Substrate.CallHash>,
        blockNumber: BlockNumber,
        blockTime: BlockTime
    ) -> [(Substrate.CallHash, MultisigDefinitionWithTime?)] {
        callHashes
            .compactMap { callHash in
                let key = SubscriptionResult.Key.pendingOperation(with: callHash)

                // only modified definitions are sent in the update
                guard let json = state.values[key] else {
                    return nil
                }

                do {
                    let optDefinition = try json.map(
                        to: MultisigPallet.MultisigDefinition?.self,
                        with: state.context
                    )

                    if let definition = optDefinition {
                        let timestamp = BlockTimestampEstimator.estimateTimestamp(
                            for: definition.timepoint.height,
                            currentBlock: blockNumber,
                            blockTimeInMillis: blockTime
                        )

                        let model = MultisigDefinitionWithTime(
                            definition: definition,
                            timestamp: timestamp
                        )

                        return (callHash, model)
                    } else {
                        return (callHash, nil)
                    }
                } catch {
                    logger.error("Unexpected definition: \(json)")
                    return nil
                }
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
    let blockHash: Data?

    init(
        values: [BatchStorageSubscriptionResultValue],
        blockHashJson: JSON,
        context: [CodingUserInfoKey: Any]?
    ) throws {
        self.context = context
        self.values = values.reduce(into: [String: JSON]()) {
            if let mappingKey = $1.mappingKey {
                $0[mappingKey] = $1.value
            }
        }

        blockHash = try blockHashJson.map(to: Data?.self, with: context)
    }
}
