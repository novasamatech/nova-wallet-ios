import Foundation
import Operation_iOS

protocol HydraAavePoolsServiceProtocol: ApplicationServiceProtocol &
    BaseObservableStateStoreProtocol where RemoteState == [HydraAave.PoolData] {}

final class HydraAavePoolsService: BaseObservableStateStore<[HydraAave.PoolData]> {
    let trigger: any ChainPollingStateStoring
    let apiFactory: HydraAaveTradeExecutorFactoryProtocol
    let operationQueue: OperationQueue
    let workingQueue: DispatchQueue

    private var isActive: Bool = false
    private var currentBlockHash: BlockHashData?
    private let callStore = CancellableCallStore()

    init(
        trigger: any ChainPollingStateStoring,
        apiFactory: HydraAaveTradeExecutorFactoryProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue,
        logger: LoggerProtocol
    ) {
        self.trigger = trigger
        self.apiFactory = apiFactory
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue

        super.init(logger: logger)
    }
}

private extension HydraAavePoolsService {
    func performSync() {
        if let currentBlockHash {
            performPoll(for: currentBlockHash)
        } else {
            subscribeBlockHash()
        }
    }

    func stopSync() {
        trigger.remove(observer: self)
        currentBlockHash = nil

        callStore.cancel()
    }

    func subscribeBlockHash() {
        trigger.add(
            observer: self,
            sendStateOnSubscription: true,
            queue: workingQueue
        ) { [weak self] _, state in
            guard let self, let newBlockHash = state?.blockHash else {
                return
            }

            mutex.lock()

            defer {
                mutex.unlock()
            }

            currentBlockHash = newBlockHash

            performPoll(for: newBlockHash)
        }
    }

    func performPoll(for blockHash: BlockHashData) {
        logger.debug("Polling on \(blockHash.toHex())")

        let fetchPoolsWrapper = apiFactory.createAaveTradePools(
            for: blockHash.toHex(includePrefix: true)
        )

        executeCancellable(
            wrapper: fetchPoolsWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: workingQueue,
            mutex: mutex
        ) { [weak self] result in
            guard let self else {
                return
            }

            switch result {
            case let .success(pools):
                logger.debug("Received: \(String(describing: pools))")

                stateObservable.state = pools
            case let .failure(error):
                logger.error("Unexpected error: \(error)")
            }
        }
    }
}

extension HydraAavePoolsService: HydraAavePoolsServiceProtocol {
    func setup() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard !isActive else {
            return
        }

        isActive = true

        performSync()
    }

    func throttle() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard isActive else {
            return
        }

        isActive = false

        stopSync()
    }
}
