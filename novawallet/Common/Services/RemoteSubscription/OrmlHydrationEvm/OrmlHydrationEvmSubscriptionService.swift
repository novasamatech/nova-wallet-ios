import Foundation

final class OrmlHydrationEvmSubscriptionService: BaseSyncService {
    let chainAssetId: ChainAssetId
    let accountId: AccountId
    let trigger: any ChainPollingStateStoring
    let operationQueue: OperationQueue
    let callbackQueue: DispatchQueue
    let workingQueue: DispatchQueue
    let callbackClosure: (AssetBalance, BlockHashData) -> Void
    let queryFactory: OrmlHydrationEvmWalletQueryFactoryProtocol

    private var balance: AssetBalance?
    private var currentBlockHash: BlockHashData?
    private let callStore = CancellableCallStore()

    init(
        chainAssetId: ChainAssetId,
        accountId: AccountId,
        trigger: any ChainPollingStateStoring,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue,
        logger: LoggerProtocol,
        callbackQueue: DispatchQueue,
        callbackClosure: @escaping (AssetBalance, BlockHashData) -> Void
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

    override func performSyncUp() {
        guard let blockHash = currentBlockHash else {
            subscribeBlockHash()
            return
        }

        logger.debug("Block hash already exist: \(blockHash)")

        pollBalance(on: blockHash)
    }

    override func stopSyncUp() {
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

    func pollBalance(on blockHash: BlockHashData) {
        logger.debug("Polling \(chainAssetId) balance for \(accountId.toHex()) on \(blockHash.toHex())")

        callStore.cancel()

        let wrapper = queryFactory.queryBalanceWrapper(
            for: accountId,
            chainAssetId: chainAssetId,
            blockHash: blockHash
        )

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: callbackQueue,
            mutex: mutex
        ) { [weak self] result in
            guard let self else {
                return
            }

            switch result {
            case let .success(balance):
                logger.debug("Polled balance: \(balance)")
                handle(newBalance: balance, blockHash: blockHash)
                completeImmediate(nil)
            case let .failure(error):
                completeImmediate(error)
            }
        }
    }

    func handle(newBalance: AssetBalance, blockHash: BlockHashData) {
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
