import Foundation
import Operation_iOS

protocol CloudBackupSyncServiceProtocol {
    func subscribeState(
        _ observer: AnyObject,
        notifyingIn queue: DispatchQueue,
        closure: @escaping (CloudBackupSyncState) -> Void
    )

    func unsubscribeState(_ observer: AnyObject)

    func getState() -> CloudBackupSyncState

    func syncUp()

    func applyChanges(
        notifyingIn queue: DispatchQueue,
        closure: @escaping (Result<CloudBackupSyncResult.Changes?, Error>) -> Void
    )
}

final class CloudBackupSyncService {
    let applyUpdateFactory: CloudBackupUpdateApplicationFactoryProtocol
    let updateCalculationFactory: CloudBackupUpdateCalculationFactoryProtocol
    let syncMetadataManager: CloudBackupSyncMetadataManaging
    let fileManager: CloudBackupFileManaging
    let workQueue: DispatchQueue
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private let mutex = NSLock()
    private let cancellableStore = CancellableCallStore()
    private var stateObservable: Observable<CloudBackupSyncState>

    init(
        updateCalculationFactory: CloudBackupUpdateCalculationFactoryProtocol,
        applyUpdateFactory: CloudBackupUpdateApplicationFactoryProtocol,
        syncMetadataManager: CloudBackupSyncMetadataManaging,
        fileManager: CloudBackupFileManaging,
        operationQueue: OperationQueue,
        workQueue: DispatchQueue,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.updateCalculationFactory = updateCalculationFactory
        self.applyUpdateFactory = applyUpdateFactory
        self.syncMetadataManager = syncMetadataManager
        self.fileManager = fileManager
        self.workQueue = workQueue
        self.operationQueue = operationQueue
        self.logger = logger

        let lastSyncDate = syncMetadataManager.getLastSyncDate()

        if syncMetadataManager.isBackupEnabled {
            if fileManager.getFileUrl() != nil {
                stateObservable = .init(state: .enabled(nil, lastSyncDate: lastSyncDate))
            } else {
                stateObservable = .init(state: .unavailable(lastSyncDate: lastSyncDate))
            }
        } else {
            stateObservable = .init(state: .disabled(lastSyncDate: lastSyncDate))
        }
    }

    private func handle(syncResult: CloudBackupSyncResult) {
        guard syncMetadataManager.isBackupEnabled else {
            return
        }

        logger.debug("Did complete sync: \(syncResult)")

        stateObservable.state = .enabled(
            syncResult,
            lastSyncDate: syncMetadataManager.getLastSyncDate()
        )
    }

    private func performSync() {
        guard syncMetadataManager.isBackupEnabled else {
            cancellableStore.cancel()
            stateObservable.state = .disabled(lastSyncDate: syncMetadataManager.getLastSyncDate())
            return
        }

        guard let remoteUrl = fileManager.getFileUrl() else {
            cancellableStore.cancel()
            stateObservable.state = .unavailable(lastSyncDate: syncMetadataManager.getLastSyncDate())
            return
        }

        guard !cancellableStore.hasCall else {
            logger.warning("Skipping as already syncing")
            return
        }

        let wrapper = updateCalculationFactory.createUpdateCalculation(for: remoteUrl)

        stateObservable.state = .enabled(nil, lastSyncDate: syncMetadataManager.getLastSyncDate())

        logger.debug("Will start sync")

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: cancellableStore,
            runningCallbackIn: workQueue,
            mutex: mutex
        ) { [weak self] result in
            switch result {
            case let .success(syncResult):
                self?.handle(syncResult: syncResult)
            case let .failure(error):
                self?.logger.error("Unexpected error: \(error)")
                self?.handle(syncResult: .issue(.internalFailure))
            }
        }
    }

    private func performChangesApply(
        notifyingIn queue: DispatchQueue,
        closure: @escaping (Result<CloudBackupSyncResult.Changes?, Error>) -> Void
    ) {
        guard
            case let .enabled(result, _) = stateObservable.state,
            case let .changes(changes) = result else {
            logger.warning("No changes to apply")

            dispatchInQueueWhenPossible(queue) {
                closure(.success(nil))
            }

            return
        }

        cancellableStore.cancel()

        let wrapper = applyUpdateFactory.createUpdateApplyOperation(for: changes)

        stateObservable.state = .enabled(nil, lastSyncDate: syncMetadataManager.getLastSyncDate())

        logger.debug("Will start applying changes")

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: cancellableStore,
            runningCallbackIn: workQueue,
            mutex: mutex
        ) { [weak self] result in
            switch result {
            case .success:
                dispatchInQueueWhenPossible(queue) {
                    closure(.success(changes))
                }

                self?.logger.debug("Did complete applying changes")

                self?.performSync()
            case let .failure(error):
                dispatchInQueueWhenPossible(queue) {
                    closure(.failure(error))
                }

                self?.logger.error("Update application error: \(error)")
                self?.handle(syncResult: .issue(.internalFailure))
            }
        }
    }
}

extension CloudBackupSyncService: CloudBackupSyncServiceProtocol {
    func subscribeState(
        _ observer: AnyObject,
        notifyingIn queue: DispatchQueue,
        closure: @escaping (CloudBackupSyncState) -> Void
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        stateObservable.addObserver(
            with: observer,
            sendStateOnSubscription: true,
            queue: queue
        ) { _, newState in
            closure(newState)
        }
    }

    func unsubscribeState(_ observer: AnyObject) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        stateObservable.removeObserver(by: observer)
    }

    func getState() -> CloudBackupSyncState {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return stateObservable.state
    }

    func syncUp() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        performSync()
    }

    func applyChanges(
        notifyingIn queue: DispatchQueue,
        closure: @escaping (Result<CloudBackupSyncResult.Changes?, Error>) -> Void
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        performChangesApply(notifyingIn: queue, closure: closure)
    }
}
