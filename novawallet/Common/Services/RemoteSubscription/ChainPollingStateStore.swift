import Foundation

protocol ChainPollingStateStoring: ApplicationServiceProtocol & BaseObservableStateStoreProtocol
    where RemoteState == BlockHash {}

final class ChainPollingStateStore: BaseObservableStateStore<BlockHash> {
    
    private var subscription: CallbackBatchStorageSubscription<BatchSubscriptionHandler>?
    
    let chainId: ChainModel.Id
    let chainRegistry: ChainRegistryProtocol
    let logger: LoggerProtocol
    
    init(
        chainId: ChainModel.Id,
        chainRegistry: ChainRegistryProtocol,
        logger: LoggerProtocol
    ) {
        self.subscription = subscription
        self.chainId = chainId
        self.chainRegistry = chainRegistry
        self.logger = logger
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
        
        
    }
    
    func throttle() {}
}
