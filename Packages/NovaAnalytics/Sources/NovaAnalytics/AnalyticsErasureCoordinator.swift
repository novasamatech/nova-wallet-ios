import Foundation
import Operation_iOS
import SDKLogger

// Persist the wipe obligation so it survives process termination.
final class AnalyticsErasureCoordinator {
    private let consent: AnalyticsConsentManagerProtocol
    private let queue: AnalyticsEventQueueProtocol
    private let operationQueue: OperationQueue
    private let logger: SDKLoggerProtocol

    private let mutex = NSLock()
    private var isOwed: Bool
    private var outstandingClears: Int = 0

    init(
        consent: AnalyticsConsentManagerProtocol,
        queue: AnalyticsEventQueueProtocol,
        operationQueue: OperationQueue,
        logger: SDKLoggerProtocol
    ) {
        self.consent = consent
        self.queue = queue
        self.operationQueue = operationQueue
        self.logger = logger

        isOwed = consent.isErasureOwed
    }

    func drainOwed() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard isOwed else {
            return
        }

        logger.info("Analytics erasure owed from a previous launch, wiping the queue")

        scheduleLocked()
    }

    // Each withdrawal clears only rows queued before it; later consent must keep its rows.
    func request() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        isOwed = true
        consent.setErasureOwed(true)

        scheduleLocked()
    }

    // Uploads remain blocked until the owed wipe succeeds.
    func retryIfOwed() -> Bool {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard isOwed else {
            return false
        }

        if outstandingClears == 0 {
            scheduleLocked()
        }

        return true
    }
}

// MARK: - Private

private extension AnalyticsErasureCoordinator {
    func scheduleLocked() {
        outstandingClears += 1

        let clearOperation = queue.clearOperation()

        // Settle on the same queue so subsequent enqueues see the completed wipe.
        let settleOperation = ClosureOperation<Void> { [weak self] in
            guard let self else {
                return
            }

            mutex.lock()

            defer {
                mutex.unlock()
            }

            outstandingClears -= 1

            try clearOperation.extractNoCancellableResultData()

            releaseIfSettledLocked()
        }

        settleOperation.addDependency(clearOperation)

        let wipeWrapper = CompoundOperationWrapper(
            targetOperation: settleOperation,
            dependencies: [clearOperation]
        )

        execute(
            wrapper: wipeWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: nil
        ) { [weak self] result in
            if case let .failure(error) = result {
                self?.logger.error("Analytics queue wipe failed, retrying on the next flush: \(error)")
            }
        }
    }

    func releaseIfSettledLocked() {
        guard outstandingClears == 0 else {
            return
        }

        isOwed = false
        consent.setErasureOwed(false)
    }
}
