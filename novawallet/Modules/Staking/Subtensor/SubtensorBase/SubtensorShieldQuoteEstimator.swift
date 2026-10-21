import Foundation
import Operation_iOS

enum SubtensorShieldQuoteEstimatorError: Error {
    case timedOut
}

final class SubtensorShieldQuoteEstimator {
    var onQuote: ((SubtensorShieldQuote?) -> Void)?

    private let submissionOperationFactory: SubtensorSubmissionOperationFactoryProtocol
    private let operationQueue: OperationQueue
    private let logger: LoggerProtocol
    private let callStore = CancellableCallStore()

    private var pendingOperation: SubtensorOperation?
    private var quotedOperation: SubtensorOperation?
    private var isInFlight = false
    private var startBlock: BlockNumber?
    private var lastBlock: BlockNumber?
    private var failures = 0

    init(
        submissionOperationFactory: SubtensorSubmissionOperationFactoryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.submissionOperationFactory = submissionOperationFactory
        self.operationQueue = operationQueue
        self.logger = logger
    }

    deinit {
        callStore.cancel()
    }

    func schedule(_ operation: SubtensorOperation) -> Bool {
        guard operation != pendingOperation, !(isInFlight && operation == quotedOperation) else {
            return false
        }

        callStore.cancel()
        pendingOperation = operation
        isInFlight = false

        return true
    }

    func cancel() {
        callStore.cancel()
        pendingOperation = nil
        isInFlight = false
    }

    func startPending() {
        guard let operation = pendingOperation else {
            return
        }

        pendingOperation = nil

        if operation != quotedOperation {
            quotedOperation = operation
            failures = 0
        }

        isInFlight = true
        startBlock = lastBlock

        executeCancellable(
            wrapper: submissionOperationFactory.createShieldQuoteWrapper(for: operation),
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            self?.complete(with: result)
        }
    }

    func didReceiveBlock(_ blockNumber: BlockNumber) {
        lastBlock = blockNumber

        guard isInFlight else {
            return
        }

        guard let startBlock else {
            self.startBlock = blockNumber
            return
        }

        guard blockNumber > startBlock + SubtensorFlowConstants.shieldQuoteTimeoutBlocks else {
            return
        }

        callStore.cancel()
        complete(with: .failure(SubtensorShieldQuoteEstimatorError.timedOut))
    }
}

private extension SubtensorShieldQuoteEstimator {
    func complete(with result: Result<SubtensorShieldQuote?, Error>) {
        isInFlight = false

        switch result {
        case let .success(quote):
            failures = 0
            onQuote?(quote)
        case let .failure(error):
            failures += 1
            logger.warning("Shield quote failed: \(error)")

            if failures >= SubtensorFlowConstants.shieldQuoteAttempts {
                onQuote?(nil)
            }
        }
    }
}
