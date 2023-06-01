import Foundation
import RobinHood
import SubstrateSdk

protocol SyncServiceProtocol {
    func syncUp(afterDelay: TimeInterval, ignoreIfSyncing: Bool)
    func stopSyncUp()
    func setup()
}

extension SyncServiceProtocol {
    func syncUp() {
        syncUp(afterDelay: 0, ignoreIfSyncing: true)
    }
}

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

    func markSyncingImmediate() {
        isSyncing = true
    }

    func complete(_ error: Error?) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        completeImmediate(error)
    }

    func completeImmediate(_ error: Error?) {
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

        scheduler.cancel()

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

extension BaseSyncService: SyncServiceProtocol {
    func syncUp(afterDelay: TimeInterval, ignoreIfSyncing: Bool) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard isActive else {
            return
        }

        if ignoreIfSyncing, isSyncing {
            return
        }

        if isSyncing {
            stopSyncUp()

            isSyncing = false
        }

        if afterDelay > 0 {
            guard !scheduler.isScheduled else {
                return
            }

            scheduler.notifyAfter(afterDelay)

        } else {
            scheduler.cancel()

            isSyncing = true

            performSyncUp()
        }
    }
}
