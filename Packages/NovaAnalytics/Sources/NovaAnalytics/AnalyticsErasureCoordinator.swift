import Foundation
import Operation_iOS
import SDKLogger

/// The queue wipe owed after a consent withdrawal, persisted so that process death cannot cancel it.
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

    /// Every request gets its own clear so that the serial queue orders it after exactly the rows
    /// recorded before the withdrawal, and never after rows recorded under a later consent.
    func request() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        isOwed = true
        consent.setErasureOwed(true)

        scheduleLocked()
    }

    /// Re-arms a failed wipe and reports whether one is still owed, in which case nothing may upload.
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

        // Settling on the analytics queue itself makes the outcome visible to every enqueue behind the clear.
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
