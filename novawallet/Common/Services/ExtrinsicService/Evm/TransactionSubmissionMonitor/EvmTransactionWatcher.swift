import Foundation
import Operation_iOS
import SubstrateSdk

final class EvmTransactionWatcher {
    typealias Completion = (Result<EvmTransactionMonitorSubmission, Error>) -> Void

    let queryOperationFactory: EthereumOperationFactoryProtocol
    let headsConnection: JSONRPCEngine?
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
    private var headsSubscriptionId: UInt16?
    private var lastCheckStartedAt: Date?

    init(
        queryOperationFactory: EthereumOperationFactoryProtocol,
        headsConnection: JSONRPCEngine?,
        timing: EvmTransactionMonitorTiming,
        processingQueue: DispatchQueue,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.queryOperationFactory = queryOperationFactory
        self.headsConnection = headsConnection
        self.timing = timing
        self.processingQueue = processingQueue
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

extension EvmTransactionWatcher {
    func start(watching transaction: EvmSubmittedTransaction, completion: @escaping Completion) {
        guard !isFinished else { return }

        self.transaction = transaction
        self.completion = completion
        state = EvmTransactionMonitorState(nonce: transaction.nonce, timing: timing, startedAt: Date())

        logger.debug("EVM monitor: watching \(transaction.transactionHash) nonce \(transaction.nonce)")

        deadlineScheduler.notifyAfter(timing.waitBudget)
        pollScheduler.notifyAfter(timing.pollInterval)

        subscribeHeads()
    }

    func stop() {
        guard !isFinished else { return }

        tearDown()
        completion = nil

        logger.debug("EVM monitor: stopped \(transaction?.transactionHash ?? "before start")")
    }
}

private extension EvmTransactionWatcher {
    enum Trigger: String {
        case timer
        case head
    }

    func subscribeHeads() {
        guard let headsConnection else { return }

        typealias HeadsUpdate = JSONRPCSubscriptionUpdate<EvmSubscriptionMessage.NewHeadsUpdate>

        let updateClosure: (HeadsUpdate) -> Void = { [weak self] _ in
            self?.processingQueue.async { [weak self] in
                self?.handleHead()
            }
        }

        let failureClosure: (Error, Bool) -> Void = { [weak self] error, _ in
            self?.logger.warning("EVM monitor: heads subscription failed \(error)")
        }

        do {
            headsSubscriptionId = try headsConnection.subscribe(
                EvmSubscriptionMessage.subscribeMethod,
                params: EvmSubscriptionMessage.NewHeadsParams(),
                unsubscribeMethod: EvmSubscriptionMessage.unsubscribeMethod,
                updateClosure: updateClosure,
                failureClosure: failureClosure
            )
        } catch {
            logger.warning("EVM monitor: heads subscription unavailable \(error)")
        }
    }

    func handleHead() {
        guard !isFinished else { return }

        if let lastCheckStartedAt, Date().timeIntervalSince(lastCheckStartedAt) < timing.minHeadCheckSpacing {
            return
        }

        startCheck(trigger: .head)
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
            pollScheduler.notifyAfter(timing.pollInterval)
        case .verifyDropped:
            verifyDropped()
        case let .success(transactionHash, blockHash):
            let status = EvmTransactionMonitorSubmission.TransactionStatus.success(
                .init(transactionHash: transactionHash, blockHash: blockHash)
            )
            finish(with: .success(EvmTransactionMonitorSubmission(status: status)))
        case let .failure(transactionHash):
            let status = EvmTransactionMonitorSubmission.TransactionStatus.failure(
                .init(transactionHash: transactionHash)
            )
            finish(with: .success(EvmTransactionMonitorSubmission(status: status)))
        case .dropped:
            logger.warning("EVM monitor: \(transaction.transactionHash) dropped")
            finish(with: .failure(EvmTransactionMonitorError.dropped(transactionHash: transaction.transactionHash)))
        case .stillPending:
            logger.warning("EVM monitor: \(transaction.transactionHash) still pending")
            let error = EvmTransactionMonitorError.stillPending(transactionHash: transaction.transactionHash)
            finish(with: .failure(error))
        }
    }

    func finish(with result: Result<EvmTransactionMonitorSubmission, Error>) {
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

        if let headsSubscriptionId {
            headsConnection?.cancelForIdentifier(headsSubscriptionId)
            self.headsSubscriptionId = nil
        }
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
