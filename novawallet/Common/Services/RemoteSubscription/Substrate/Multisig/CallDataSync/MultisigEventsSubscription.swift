import Foundation
import Operation_iOS
import SubstrateSdk

protocol MultisigEventsSubscriber: AnyObject {
    func didReceive(
        events: [MultisigEvent],
        blockHash: Data,
        chainId: ChainModel.Id
    )
}

final class MultisigEventsSubscription: WebSocketSubscribing {
    let chainId: ChainModel.Id
    let chainRegistry: ChainRegistryProtocol
    let logger: LoggerProtocol?

    private let operationQueue: OperationQueue
    private let workingQueue: DispatchQueue

    private var subscription: CallbackStorageSubscription<[EventRecord]>?
    private weak var subscriber: MultisigEventsSubscriber?

    init(
        chainId: ChainModel.Id,
        chainRegistry: ChainRegistryProtocol,
        subscriber: MultisigEventsSubscriber,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue,
        logger: LoggerProtocol? = nil
    ) {
        self.chainId = chainId
        self.chainRegistry = chainRegistry
        self.subscriber = subscriber
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue
        self.logger = logger

        do {
            try subscribeRemote()
        } catch {
            logger?.error("Failed to subscribe to system.events: \(error)")
        }
    }

    deinit {
        unsubscribeRemote()
    }
}

// MARK: - Private

private extension MultisigEventsSubscription {
    func unsubscribeRemote() {
        subscription?.unsubscribe()
        subscription = nil
    }

    func subscribeRemote() throws {
        let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chainId)
        let connection = try chainRegistry.getConnectionOrError(for: chainId)

        let request = UnkeyedSubscriptionRequest(
            storagePath: SystemPallet.eventsPath,
            localKey: ""
        )

        subscription = CallbackStorageSubscription(
            request: request,
            connection: connection,
            runtimeService: runtimeProvider,
            repository: nil,
            operationQueue: operationQueue,
            callbackWithBlockQueue: workingQueue
        ) { [weak self] result in
            switch result {
            case let .success(eventRecordsWithBlock):
                self?.handle(eventRecordsWithBlock, using: runtimeProvider.fetchCoderFactoryOperation())
            case let .failure(error):
                self?.logger?.error("Failed to subscribe System.Events: \(error)")
            }
        }
    }

    func handle(
        _ eventRecordsWithBlock: CallbackStorageSubscriptionResult<[EventRecord]>,
        using codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) {
        guard
            let blockHash = eventRecordsWithBlock.blockHash,
            let events = eventRecordsWithBlock.value
        else {
            return
        }

        execute(
            operation: codingFactoryOperation,
            inOperationQueue: operationQueue,
            runningCallbackIn: workingQueue
        ) { [weak self] result in
            guard let self else { return }
            switch result {
            case let .success(codingFactory):
                let multisigEvents = events.compactMap {
                    MultisigEventMatcher(codingFactory: codingFactory).matchMultisig(
                        event: $0.event
                    )
                }

                guard !multisigEvents.isEmpty else { return }

                self.subscriber?.didReceive(
                    events: multisigEvents,
                    blockHash: blockHash,
                    chainId: self.chainId
                )
            case let .failure(error):
                logger?.error("Failed to fetch coder factory: \(error)")
            }
        }
    }
}
