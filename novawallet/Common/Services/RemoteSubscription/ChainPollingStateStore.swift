import Foundation

protocol ChainPollingStateStoring: ApplicationServiceProtocol & BaseObservableStateStoreProtocol
    where RemoteState == BlockHashData {}

final class ChainPollingStateStore: BaseObservableStateStore<BlockHashData> {
    private var subscription: CallbackBatchStorageSubscription<BatchSubscriptionHandler>?

    let chainId: ChainModel.Id
    let chainRegistry: ChainRegistryProtocol
    let workingQueue: DispatchQueue
    let operationQueue: OperationQueue

    init(
        chainId: ChainModel.Id,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue,
        logger: LoggerProtocol
    ) {
        self.chainId = chainId
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue

        super.init(logger: logger)
    }
}

private extension ChainPollingStateStore {
    func setupSubscription() {
        do {
            let connection = try chainRegistry.getConnectionOrError(for: chainId)
            let runtimeService = try chainRegistry.getRuntimeProviderOrError(for: chainId)

            subscription = CallbackBatchStorageSubscription(
                requests: [
                    BatchStorageSubscriptionRequest(
                        innerRequest: UnkeyedSubscriptionRequest(
                            storagePath: SystemPallet.blockNumberPath,
                            localKey: ""
                        ),
                        mappingKey: nil
                    )
                ],
                connection: connection,
                runtimeService: runtimeService,
                repository: nil,
                operationQueue: operationQueue,
                callbackQueue: workingQueue
            ) { [weak self] result in
                guard let self else {
                    return
                }

                switch result {
                case let .success(change):
                    logger.debug("New block hash: \(String(describing: change.blockHash?.toHexString()))")
                    stateObservable.state = change.blockHash
                case let .failure(error):
                    logger.error("Unexpected error: \(error)")
                }
            }

            subscription?.subscribe()
        } catch {
            logger.error("Unexpected error: \(error)")
        }
    }
}

extension ChainPollingStateStore: ChainPollingStateStoring {
    func setup() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard subscription == nil else {
            return
        }

        setupSubscription()
    }

    func throttle() {
        subscription?.unsubscribe()
        subscription = nil
    }
}
