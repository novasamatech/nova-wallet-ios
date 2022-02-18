import Foundation
import SubstrateSdk

protocol NftSyncServiceProtocol {
    func syncUp()
}

class BaseNftSyncService {
    let retryStrategy: ReconnectionStrategyProtocol
    let logger: LoggerProtocol?

    private(set) var retryAttempt: Int = 0
    private(set) var isSyncing: Bool = false
    private let mutex = NSLock()

    private lazy var scheduler: Scheduler = {
        let scheduler = Scheduler(with: self, callbackQueue: DispatchQueue.global())
        return scheduler
    }()

    init(retryStrategy: ReconnectionStrategyProtocol, logger: LoggerProtocol?) {
        self.retryStrategy = retryStrategy
        self.logger = logger
    }

    private func performSyncUpIfNeeded() {
        guard !isSyncing else {
            logger?.debug("Tried to sync up chains but already syncing")
            return
        }

        isSyncing = true
        retryAttempt += 1

        logger?.debug("Will start chain sync with attempt \(retryAttempt)")

        executeSync()
    }

    func executeSync() {
        fatalError("Must be implemented by child class")
    }

    func complete(_ error: Error?) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        isSyncing = false

        if let error = error {
            logger?.error("Sync failed with error: \(error)")

            retry()
        } else {
            logger?.debug("Sync completed")

            retryAttempt = 0
        }
    }

    func retry() {
        if let nextDelay = retryStrategy.reconnectAfter(attempt: retryAttempt) {
            logger?.debug("Scheduling chain sync retry after \(nextDelay)")

            scheduler.notifyAfter(nextDelay)
        }
    }
}

extension BaseNftSyncService: NftSyncServiceProtocol {
    func syncUp() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if retryAttempt > 0 {
            scheduler.cancel()
        }

        performSyncUpIfNeeded()
    }
}

extension BaseNftSyncService: SchedulerDelegate {
    func didTrigger(scheduler _: SchedulerProtocol) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        performSyncUpIfNeeded()
    }
}
