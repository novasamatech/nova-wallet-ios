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
    private var isInFlight: Bool = false
    private var isRequeued: Bool = false

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

    var isPending: Bool {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return isOwed
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

    func request() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        isOwed = true
        consent.setErasureOwed(true)

        guard !isInFlight else {
            // The running clear may already have passed rows enqueued since it was scheduled.
            isRequeued = true

            return
        }

        scheduleLocked()
    }

    func retry() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        scheduleLocked()
    }
}

// MARK: - Private

private extension AnalyticsErasureCoordinator {
    func scheduleLocked() {
        guard !isInFlight else {
            return
        }

        isInFlight = true
        isRequeued = false

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

            isInFlight = false

            try clearOperation.extractNoCancellableResultData()

            completeLocked()
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

    func completeLocked() {
        guard !isRequeued else {
            scheduleLocked()

            return
        }

        isOwed = false
        consent.setErasureOwed(false)
    }
}
