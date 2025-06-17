import Foundation
import Operation_iOS
import SubstrateSdk

protocol MultisigEventsSubscriber: AnyObject {
    func didReceive(
        event: MultisigEvent,
        blockHash: Data,
        chainId: ChainModel.Id
    )
}

final class MultisigEventsSubscription: WebSocketSubscribing {
    let chainId: ChainModel.Id
    let chainRegistry: ChainRegistryProtocol
    let storageFacade: StorageFacadeProtocol
    let logger: LoggerProtocol?

    private let operationQueue: OperationQueue
    private let workingQueue: DispatchQueue
    
    private var subscription: CallbackStorageSubscription<[EventRecord]>?
    private weak var subscriber: MultisigEventsSubscriber?
    
    private lazy var repository: AnyDataProviderRepository<ChainStorageItem> = {
        let coreDataRepository: CoreDataRepository<ChainStorageItem, CDChainStorageItem> =
            storageFacade.createRepository()
        return AnyDataProviderRepository(coreDataRepository)
    }()
    
    init(
        chainId: ChainModel.Id,
        chainRegistry: ChainRegistryProtocol,
        storageFacade: StorageFacadeProtocol,
        subscriber: MultisigEventsSubscriber,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue,
        logger: LoggerProtocol? = nil
    ) {
        self.chainId = chainId
        self.chainRegistry = chainRegistry
        self.storageFacade = storageFacade
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
        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainId) else {
            throw ChainRegistryError.runtimeMetadaUnavailable
        }
        
        guard let connection = chainRegistry.getConnection(for: chainId) else {
            throw ChainRegistryError.connectionUnavailable
        }
        
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
                events.forEach {
                    guard let multisigEvent = self.matchMultisig(
                        event: $0.event,
                        using: codingFactory
                    ) else { return }
                    
                    self.subscriber?.didReceive(
                        event: multisigEvent,
                        blockHash: blockHash,
                        chainId: self.chainId
                    )
                }
            case let .failure(error):
                logger?.error("Failed to fetch coder factory: \(error)")
            }
        }
    }
    
    func matchMultisig(
        event: Event,
        using codingFactory: RuntimeCoderFactoryProtocol
    ) -> MultisigEvent? {
        guard codingFactory.metadata.eventMatches(event, path: EventCodingPath.newMultisig) else {
            return nil
        }

        return if let newMultisigEvent = try? event.params.map(
            to: Multisig.NewMultisigEvent.self,
            with: codingFactory.createRuntimeJsonContext().toRawContext()
        ) {
            MultisigEvent(
                accountId: newMultisigEvent.accountId,
                callHash: newMultisigEvent.callHash
            )
        } else if let multisigApproval = try? event.params.map(
            to: Multisig.MultisigApprovalEvent.self,
            with: codingFactory.createRuntimeJsonContext().toRawContext()
        ) {
            MultisigEvent(
                accountId: multisigApproval.accountId,
                callHash: multisigApproval.callHash
            )
        } else {
            nil
        }
    }
}

struct MultisigEvent {
    let accountId: AccountId
    let callHash: CallHash
}
