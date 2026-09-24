import Foundation
import Operation_iOS

protocol HydraAavePoolsServiceProtocol: ApplicationServiceProtocol &
    BaseObservableStateStoreProtocol where RemoteState == [HydraAave.PoolData] {}

final class HydraAavePoolsService: BaseObservableStateStore<[HydraAave.PoolData]> {
    private static let individualRefreshInterval: TimeInterval = 20
    private static let failedRefreshInterval: TimeInterval = 5

    let trigger: any ChainPollingStateStoring
    let apiFactory: HydraAaveTradeExecutorFactoryProtocol
    let pairs: [HydraAave.TradePair]
    let operationQueue: OperationQueue
    let workingQueue: DispatchQueue

    private var isActive: Bool = false
    private var currentBlockHash: BlockHashData?
    private var nextPollDate: Date?
    private let callStore = CancellableCallStore()

    init(
        trigger: any ChainPollingStateStoring,
        apiFactory: HydraAaveTradeExecutorFactoryProtocol,
        pairs: [HydraAave.TradePair],
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue,
        logger: LoggerProtocol
    ) {
        self.trigger = trigger
        self.apiFactory = apiFactory
        self.pairs = pairs
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
        nextPollDate = nil

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
        guard !callStore.hasCall else {
            return
        }

        if let nextPollDate, nextPollDate > Date() {
            return
        }

        logger.debug("Polling on \(blockHash.toHex())")

        let fetchPoolsWrapper = apiFactory.createAaveTradePools(
            for: pairs,
            blockHash: blockHash.toHex(includePrefix: true)
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
            case let .success(fetchResult):
                logger.debug("Received: \(String(describing: fetchResult.pools))")

                stateObservable.state = fetchResult.pools

                switch fetchResult.source {
                case .aggregate:
                    nextPollDate = nil
                case .individual:
                    nextPollDate = Date().addingTimeInterval(Self.individualRefreshInterval)
                }
            case let .failure(error):
                logger.error("Unexpected error: \(error)")
                nextPollDate = Date().addingTimeInterval(Self.failedRefreshInterval)
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
