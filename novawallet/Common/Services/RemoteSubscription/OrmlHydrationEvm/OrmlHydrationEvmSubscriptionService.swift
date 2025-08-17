import Foundation

final class OrmlHydrationEvmSubscriptionService: BaseSyncService {
    let chainAssetId: ChainAssetId
    let accountId: AccountId
    let trigger: ChainPollingStateStoring
    let operationQueue: OperationQueue
    let callbackQueue: DispatchQueue
    let workingQueue: DispatchQueue
    let callbackClosure: (AssetBalance?, BlockHash) -> Void
    let queryFactory: OrmlHydrationEvmWalletQueryFactoryProtocol
    
    private var balance: AssetBalance?
    private var currentBlockHash: BlockHash?
    private let callStore = CancellableCallStore()
    
    init(
        chainAssetId: ChainAssetId,
        accountId: AccountId,
        trigger: ChainPollingStateStoring,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue,
        logger: LoggerProtocol,
        callbackQueue: DispatchQueue,
        callbackClosure: @escaping (AssetBalance?) -> Void
    ) {
        self.chainAssetId = chainAssetId
        self.accountId = accountId
        self.trigger = trigger
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue
        self.callbackQueue = callbackQueue
        self.callbackClosure = callbackClosure
        
        queryFactory = OrmlHydrationEvmWalletQueryFactory(
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )
        
        super.init(logger: logger)
    }
    
    override func performSync() {
        guard let blockHash = currentBlockHash else {
            subscribeBlockHash()
            return
        }
        
        logger.debug("Block hash already exist: \(currentBlockHash)")
        
        pollBalance(on: blockHash)
    }
    
    override func stopSync() {
        trigger.remove(observer: self)
        callStore.cancel()
    }
}

private extension OrmlHydrationEvmSubscriptionService {
    func subscribeBlockHash() {
        trigger.add(
            observer: self,
            sendStateOnSubscription: true,
            queue: workingQueue
        ) { [weak self] _, newState in
            guard let self, let blockHash = newState else {
                return
            }
            
            mutex.lock()
            
            defer {
                mutex.unlock()
            }
            
            currentBlockHash = blockHash
            
            pollBalance(on: blockHash)
        }
    }
    
    func pollBalance(on blockHash: BlockHash) {
        logger.debug("Polling \(chainAssetId) balance for \(accountId.toHex()) on \(blockHash)")
        
        callStore.cancel()
        
        let wrapper = queryFactory.queryBalanceWrapper(
            for: accountId,
            chainAssetId: chainAssetId
        )
        
        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: callbackQueue,
            mutex: mutex
        ) { [weak self] result in
            guard let self = else {
                return
            }
            
            switch result {
            case let .success(balance):
                logger.debug("Polled balance: \(balance)")
                handle(newBalance: balance, blockHash: blockHash)
            case let .failure(error):
                logger.error("Poll failed: \(error)")
            }
        }
    }
    
    func handle(newBalance: AssetBalance, blockHash: BlockHash) {
        guard balance != newBalance else {
            return
        }
        
        logger.debug("Updating balance")
        
        balance = newBalance
        
        dispatchInQueueWhenPossible(callbackQueue) { [weak self] in
            self?.callbackClosure(newBalance, blockHash)
        }
    }
}
