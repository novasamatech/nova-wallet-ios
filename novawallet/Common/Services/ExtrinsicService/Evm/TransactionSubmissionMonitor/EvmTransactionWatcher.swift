import Foundation
import Operation_iOS

final class EvmTransactionWatcher {
    typealias Completion = (TransactionWatchResult) -> Void

    let queryOperationFactory: EthereumOperationFactoryProtocol
    let timing: EvmTransactionMonitorTiming
    let processingQueue: DispatchQueue
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private lazy var pollScheduler = Scheduler(with: self, callbackQueue: processingQueue)
    private lazy var deadlineScheduler = Scheduler(with: self, callbackQueue: processingQueue)
    private let callStore = CancellableCallStore()

    private var transaction: EvmSubmittedTransaction?
    private var state: EvmTransactionMonitorState?
    private var completion: Completion?
    private var isFinished = false
    private var lastCheckStartedAt: Date?

    init(
        queryOperationFactory: EthereumOperationFactoryProtocol,
        timing: EvmTransactionMonitorTiming,
        processingQueue: DispatchQueue,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.queryOperationFactory = queryOperationFactory
        self.timing = timing
        self.processingQueue = processingQueue
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

extension EvmTransactionWatcher {
    func start(
        watching transaction: EvmSubmittedTransaction,
        submittedAt: Date = Date(),
        deadline: TimeInterval?,
        completion: @escaping Completion
    ) {
        guard !isFinished else { return }

        self.transaction = transaction
        self.completion = completion
        state = EvmTransactionMonitorState(
            nonce: transaction.nonce,
            timing: timing,
            startedAt: submittedAt,
            deadline: deadline
        )

        let nonce = transaction.nonce.map { String($0) } ?? "unknown"
        logger.debug("EVM monitor: watching \(transaction.transactionHash) nonce \(nonce)")

        let remainingTime = deadline.map { $0 - Date().timeIntervalSince(submittedAt) } ?? 0

        if remainingTime > 0 {
            deadlineScheduler.notifyAfter(remainingTime)
        }

        pollScheduler.notifyAfter(nextPollInterval())
    }

    func stop() {
        processingQueue.async {
            self.performStop()
        }
    }

    func checkNow() {
        processingQueue.async { [weak self] in
            guard let self, !isFinished else { return }

            startCheck(trigger: .request)
        }
    }

    func didReceiveHead() {
        guard !isFinished, let state, Date().timeIntervalSince(state.startedAt) < timing.waitBudget else { return }

        if let lastCheckStartedAt, Date().timeIntervalSince(lastCheckStartedAt) < timing.minHeadCheckSpacing {
            return
        }

        startCheck(trigger: .head)
    }
}

private extension EvmTransactionWatcher {
    enum Trigger: String {
        case timer
        case head
        case request
    }

    func performStop() {
        guard !isFinished else { return }

        tearDown()
        completion = nil

        logger.debug("EVM monitor: stopped \(transaction?.transactionHash ?? "before start")")
    }

    func nextPollInterval() -> TimeInterval {
        let age = state.map { Date().timeIntervalSince($0.startedAt) } ?? 0
        return timing.interval(forAge: age)
    }

    func startCheck(trigger: Trigger) {
        guard !isFinished, !callStore.hasCall, let transaction else { return }

        lastCheckStartedAt = Date()

        executeCancellable(
            wrapper: createCheckWrapper(for: transaction),
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: processingQueue
        ) { [weak self] result in
            switch result {
            case let .success(check):
                self?.handle(check: check, trigger: trigger)
            case .failure:
                self?.handle(check: .unavailable, trigger: trigger)
            }
        }
    }

    func createCheckWrapper(
        for transaction: EvmSubmittedTransaction
    ) -> CompoundOperationWrapper<EvmTransactionMonitorState.Check> {
        let nonceOperation = queryOperationFactory.createTransactionsCountOperation(
            for: transaction.sender,
            block: .latest
        )

        let receiptOperation = queryOperationFactory.createTransactionReceiptOperation(
            for: transaction.transactionHash
        )

        receiptOperation.addDependency(nonceOperation)

        let mapOperation = ClosureOperation<EvmTransactionMonitorState.Check> {
            guard case let .success(receipt) = receiptOperation.result else {
                return .unavailable
            }

            if let receipt {
                return .receipt(receipt)
            }

            guard case let .success(latestNonce) = nonceOperation.result else {
                return .unavailable
            }

            return .noReceipt(latestNonce: latestNonce.wrappedValue)
        }

        mapOperation.addDependency(receiptOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [nonceOperation, receiptOperation]
        )
    }

    func handle(check: EvmTransactionMonitorState.Check, trigger: Trigger) {
        guard !isFinished, var state else { return }

        let decision = state.decide(on: check, at: Date())
        self.state = state

        logger.debug("EVM monitor: \(trigger.rawValue) check \(check) -> \(decision)")

        apply(decision)
    }

    func verifyDropped() {
        guard let transaction else { return }

        let receiptOperation = queryOperationFactory.createTransactionReceiptOperation(
            for: transaction.transactionHash
        )

        executeCancellable(
            wrapper: CompoundOperationWrapper(targetOperation: receiptOperation),
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: processingQueue
        ) { [weak self] result in
            guard let self, !isFinished, let state else { return }

            let decision = state.decideVerification(result)

            logger.debug("EVM monitor: dropped verification \(result) -> \(decision)")

            apply(decision)
        }
    }

    func apply(_ decision: EvmTransactionMonitorState.Decision) {
        guard let transaction else { return }

        switch decision {
        case .wait:
            pollScheduler.notifyAfter(nextPollInterval())
        case .verifyDropped:
            verifyDropped()
        case let .success(receipt):
            finish(with: .decided(.included(Self.inclusion(from: receipt))))
        case let .failure(receipt):
            finish(with: .decided(.includedFailed(Self.inclusion(from: receipt), .evmReverted)))
        case .dropped:
            logger.warning("EVM monitor: \(transaction.transactionHash) dropped")
            finish(with: .decided(.dropped(.nonceConsumed)))
        case .stillPending:
            logger.warning("EVM monitor: \(transaction.transactionHash) still pending")
            finish(with: .undecided)
        }
    }

    static func inclusion(from receipt: EthereumTransactionReceipt) -> TransactionInclusion {
        TransactionInclusion(
            blockHash: receipt.blockHash,
            blockNumber: receipt.blockNumberValue,
            actualFee: receipt.fee
        )
    }

    func finish(with result: TransactionWatchResult) {
        guard !isFinished else { return }

        tearDown()

        let completion = completion
        self.completion = nil

        logger.debug("EVM monitor: decided \(result)")

        completion?(result)
    }

    func tearDown() {
        isFinished = true

        pollScheduler.cancel()
        deadlineScheduler.cancel()
        callStore.cancel()
    }
}

extension EvmTransactionWatcher: SchedulerDelegate {
    func didTrigger(scheduler: SchedulerProtocol) {
        guard !isFinished else { return }

        if scheduler === deadlineScheduler {
            apply(.stillPending)
        } else {
            startCheck(trigger: .timer)
        }
    }
}
