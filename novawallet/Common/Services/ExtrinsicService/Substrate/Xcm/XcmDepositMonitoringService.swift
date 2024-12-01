import Foundation
import Operation_iOS
import SubstrateSdk

protocol XcmDepositMonitoringServiceProtocol {
    func useMonitoringWrapper() -> CompoundOperationWrapper<Balance>
}

enum XcmDepositMonitoringServiceError: Error {
    case unsupportedAsset(ChainAsset)
    case timeout
}

final class XcmDepositMonitoringService {
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeProviderProtocol
    let operationQueue: OperationQueue
    let workingQueue: DispatchQueue
    let logger: LoggerProtocol
    let blockEventsQueryFactory: BlockEventsQueryFactoryProtocol
    let tokenDepositEventMatchingFactory: TokenDepositEventMatcherFactoryProtocol
    let accountId: AccountId
    let chainAsset: ChainAsset
    let timeout: TimeInterval

    private var subscription: WalletRemoteSubscriptionProtocol?

    private var state: TokenDepositEvent?
    private var notificationClosure: ((Result<TokenDepositEvent, Error>) -> Void)?
    private var scheduler: SchedulerProtocol?
    private var detectionCallsStore: [Data: CancellableCallStore] = [:]
    private let mutex = NSLock()

    init(
        accountId: AccountId,
        chainAsset: ChainAsset,
        timeout: TimeInterval = 90,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue,
        logger: LoggerProtocol
    ) {
        self.accountId = accountId
        self.chainAsset = chainAsset
        self.timeout = timeout
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue
        self.logger = logger

        blockEventsQueryFactory = BlockEventsQueryFactory(operationQueue: operationQueue, logger: logger)
        tokenDepositEventMatchingFactory = TokenDepositEventMatcherFactory(logger: logger)
    }

    private func notifyAboutStateIfNeeded() {
        if let state {
            let closureToNotify = notificationClosure
            notificationClosure = nil

            workingQueue.async {
                closureToNotify?(.success(state))
            }
        }
    }

    private func notifyTimeout() {
        let closureToNotify = notificationClosure
        notificationClosure = nil

        workingQueue.async {
            closureToNotify?(.failure(XcmDepositMonitoringServiceError.timeout))
        }
    }

    private func clearTimeoutScheduler() {
        scheduler?.cancel()
        scheduler = nil
    }

    private func setupTimeoutScheduler() {
        scheduler = Scheduler(with: self, callbackQueue: workingQueue)
        scheduler?.notifyAfter(timeout)
    }

    private func fetchBlockAndDetectDeposit(
        for hash: Data,
        accountId: AccountId,
        eventMatcher: TokenDepositEventMatching
    ) {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let eventsWrapper = blockEventsQueryFactory.queryInherentEventsWrapper(
            from: connection,
            runtimeProvider: runtimeProvider,
            blockHash: hash
        )

        let matchingOperation = ClosureOperation<TokenDepositEvent?> {
            let events = try eventsWrapper.targetOperation.extractNoCancellableResultData()
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            let allEvents = events.initialization + events.finalization

            for event in allEvents {
                if
                    let deposit = eventMatcher.matchDeposit(event: event, using: codingFactory),
                    deposit.accountId == accountId {
                    return deposit
                }
            }

            return nil
        }

        matchingOperation.addDependency(codingFactoryOperation)
        matchingOperation.addDependency(eventsWrapper.targetOperation)

        let totalWrapper = eventsWrapper
            .insertingHead(operations: [codingFactoryOperation])
            .insertingTail(operation: matchingOperation)

        let callStore = CancellableCallStore()
        detectionCallsStore[hash] = callStore

        executeCancellable(
            wrapper: totalWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: workingQueue,
            mutex: mutex
        ) { [weak self] result in
            guard let self else {
                return
            }

            detectionCallsStore[hash] = nil

            switch result {
            case let .success(deposit):
                if let deposit {
                    logger.debug("Received deposit")
                    state = deposit
                    notifyAboutStateIfNeeded()
                } else {
                    logger.debug("No deposit in the block")
                }
            case let .failure(error):
                logger.debug("Block processing failed: \(error)")
            }
        }
    }

    // MARK: Protected interface

    private func setupNotificationClosure(_ closure: @escaping (Result<TokenDepositEvent, Error>) -> Void) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if let state {
            workingQueue.async {
                closure(.success(state))
            }
            return
        }

        if subscription == nil {
            workingQueue.async {
                closure(.failure(XcmDepositMonitoringServiceError.unsupportedAsset(self.chainAsset)))
            }
            return
        }

        notificationClosure = closure

        setupTimeoutScheduler()
    }

    private func setupIfNeeded() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard subscription == nil else {
            return
        }

        guard let eventMatcher = tokenDepositEventMatchingFactory.createMatcher(for: chainAsset) else {
            logger.error("Unsupported asset: \(chainAsset.asset.symbol)")
            return
        }

        subscription = WalletRemoteSubscription(
            runtimeProvider: runtimeProvider,
            connection: connection,
            operationQueue: operationQueue
        )

        subscription?.subscribeBalance(
            for: accountId,
            chainAsset: chainAsset,
            callbackQueue: workingQueue
        ) { [weak self] result in
            guard let self else {
                return
            }

            mutex.lock()

            defer {
                mutex.unlock()
            }

            switch result {
            case let .success(update):
                guard let blockHash = update.blockHash else {
                    logger.debug("No block found in update")
                    return
                }

                logger.debug("\(accountId.toHex()) Checking block \(blockHash.toHex()) in \(chainAsset.chain.name)")

                fetchBlockAndDetectDeposit(
                    for: blockHash,
                    accountId: accountId,
                    eventMatcher: eventMatcher
                )
            case let .failure(error):
                logger.error("Remote subscription failed: \(error)")
            }
        }
    }

    private func throttle() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        subscription?.unsubscribe()
        subscription = nil

        detectionCallsStore.values.forEach { $0.cancel() }
        detectionCallsStore = [:]

        notificationClosure = nil
    }
}

extension XcmDepositMonitoringService: SchedulerDelegate {
    func didTrigger(scheduler _: SchedulerProtocol) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        notifyTimeout()

        scheduler = nil
    }
}

extension XcmDepositMonitoringService: XcmDepositMonitoringServiceProtocol {
    func useMonitoringWrapper() -> CompoundOperationWrapper<Balance> {
        setupIfNeeded()

        let operation = AsyncClosureOperation(
            operationClosure: { completion in
                self.setupNotificationClosure { [weak self] result in
                    self?.throttle()

                    switch result {
                    case let .success(deposit):
                        completion(.success(deposit.amount))
                    case let .failure(error):
                        completion(.failure(error))
                    }
                }

            }, cancelationClosure: { [weak self] in
                self?.throttle()
            }
        )

        return CompoundOperationWrapper(targetOperation: operation)
    }
}
