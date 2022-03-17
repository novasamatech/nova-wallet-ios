import Foundation
import SubstrateSdk
import RobinHood

protocol NftSyncServiceProtocol {
    func syncUp()
}

class BaseNftSyncService {
    let repository: AnyDataProviderRepository<NftModel>
    let operationQueue: OperationQueue
    let retryStrategy: ReconnectionStrategyProtocol
    let logger: LoggerProtocol?

    private(set) var retryAttempt: Int = 0
    private(set) var isSyncing: Bool = false
    private let mutex = NSLock()

    private lazy var scheduler: Scheduler = {
        let scheduler = Scheduler(with: self, callbackQueue: DispatchQueue.global())
        return scheduler
    }()

    init(
        repository: AnyDataProviderRepository<NftModel>,
        operationQueue: OperationQueue,
        retryStrategy: ReconnectionStrategyProtocol,
        logger: LoggerProtocol?
    ) {
        self.repository = repository
        self.operationQueue = operationQueue
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

    func createRemoteFetchWrapper() -> CompoundOperationWrapper<[RemoteNftModel]> {
        fatalError("Must be implemented by child class")
    }

    func createChangesOperation(
        dependingOn remoteOperation: BaseOperation<[RemoteNftModel]>,
        localOperation: BaseOperation<[NftModel]>
    ) -> BaseOperation<DataChangesDiffCalculator<RemoteNftModel>.Changes> {
        ClosureOperation {
            let remoteItems = try remoteOperation.extractNoCancellableResultData()
            let localtems = try localOperation.extractNoCancellableResultData()
                .map { localModel in
                    RemoteNftModel(localModel: localModel)
                }

            let diffCalculator = DataChangesDiffCalculator<RemoteNftModel>()
            return diffCalculator.diff(newItems: remoteItems, oldItems: localtems)
        }
    }

    func executeSync() {
        let remoteFetchWrapper = createRemoteFetchWrapper()

        let localFetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        localFetchOperation.addDependency(remoteFetchWrapper.targetOperation)

        let changesOperation = createChangesOperation(
            dependingOn: remoteFetchWrapper.targetOperation,
            localOperation: localFetchOperation
        )

        changesOperation.addDependency(remoteFetchWrapper.targetOperation)
        changesOperation.addDependency(localFetchOperation)

        let saveOperation = repository.saveOperation({
            let changes = try changesOperation.extractNoCancellableResultData()
            return changes.newOrUpdatedItems.map { remoteModel in
                NftModel(remoteModel: remoteModel)
            }
        }, {
            let changes = try changesOperation.extractNoCancellableResultData()
            return changes.removedItems.map(\.identifier)
        })

        saveOperation.addDependency(changesOperation)

        saveOperation.completionBlock = { [weak self] in
            do {
                _ = try saveOperation.extractNoCancellableResultData()
                self?.complete(nil)
            } catch {
                self?.complete(error)
            }
        }

        let operations = remoteFetchWrapper.allOperations +
            [localFetchOperation, changesOperation, saveOperation]

        operationQueue.addOperations(operations, waitUntilFinished: false)
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
