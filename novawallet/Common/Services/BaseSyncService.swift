import Foundation
import RobinHood
import SubstrateSdk

class BaseSyncService {
    let retryStrategy: ReconnectionStrategyProtocol
    let logger: LoggerProtocol?

    private(set) var retryAttempt: Int = 0
    private(set) var isSyncing: Bool = false
    private(set) var isActive: Bool = false
    let mutex = NSLock()

    private lazy var scheduler: Scheduler = {
        let scheduler = Scheduler(with: self, callbackQueue: DispatchQueue.global())
        return scheduler
    }()

    init(
        retryStrategy: ReconnectionStrategyProtocol = ExponentialReconnection(),
        logger: LoggerProtocol? = Logger.shared
    ) {
        self.retryStrategy = retryStrategy
        self.logger = logger
    }

    func performSyncUp() {
        fatalError("Method must be overriden by child class")
    }

    func stopSyncUp() {
        fatalError("Method must be overriden by child class")
    }

    func complete(_ error: Error?) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard isActive else {
            return
        }

        isSyncing = false

        if let error = error {
            logger?.error("Sync failed with error: \(error)")

            retryAttempt += 1

            retry()
        } else {
            logger?.debug("Sync completed")

            retryAttempt = 0
        }
    }

    private func retry() {
        if let nextDelay = retryStrategy.reconnectAfter(attempt: retryAttempt) {
            logger?.debug("Scheduling chain sync retry after \(nextDelay)")

            scheduler.notifyAfter(nextDelay)
        }
    }
}

extension BaseSyncService: ApplicationServiceProtocol {
    func setup() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard !isActive else {
            return
        }

        isActive = true
        isSyncing = true

        performSyncUp()
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

        if retryAttempt > 0, !isSyncing {
            scheduler.cancel()
        }

        if isSyncing {
            stopSyncUp()
        }

        isSyncing = false
        retryAttempt = 0
    }
}

extension BaseSyncService: SchedulerDelegate {
    func didTrigger(scheduler _: SchedulerProtocol) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        isSyncing = true

        performSyncUp()
    }
}
