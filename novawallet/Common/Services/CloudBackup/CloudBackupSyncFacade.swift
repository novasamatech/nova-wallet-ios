import Foundation

protocol CloudBackupSyncFacadeProtocol: ApplicationServiceProtocol {
    func enableBackup(
        for password: String?,
        runCompletionIn queue: DispatchQueue,
        completionClosure: @escaping (Result<Void, Error>) -> Void
    )

    func disableBackup(
        runCompletionIn queue: DispatchQueue,
        completionClosure: @escaping (Result<Void, Error>) -> Void
    )

    func subscribeState(
        _ observer: AnyObject,
        notifyingIn queue: DispatchQueue,
        closure: @escaping (CloudBackupSyncState) -> Void
    )

    func unsubscribeState(_ observer: AnyObject)

    func syncUp()
}

final class CloudBackupSyncFacade {
    let syncMetadataManager: CloudBackupSyncMetadataManaging
    let fileManager: CloudBackupFileManaging
    let syncFactory: CloudBackupSyncFactoryProtocol
    let workingQueue: DispatchQueue
    let logger: LoggerProtocol

    private var syncService: CloudBackupSyncServiceProtocol?
    private var remoteMonitor: CloudBackupUpdateMonitoring?

    private let mutex = NSLock()
    private var stateObservable: Observable<CloudBackupSyncState>

    init(
        syncFactory: CloudBackupSyncFactoryProtocol,
        syncMetadataManager: CloudBackupSyncMetadataManaging,
        fileManager: CloudBackupFileManaging,
        workingQueue: DispatchQueue,
        logger: LoggerProtocol
    ) {
        self.syncMetadataManager = syncMetadataManager
        self.fileManager = fileManager
        self.syncFactory = syncFactory
        self.workingQueue = workingQueue
        self.logger = logger

        stateObservable = .init(state: .disabled(lastSyncDate: syncMetadataManager.getLastSyncDate()))
    }

    private func handle(syncResult: CloudBackupSyncResult) {
        guard syncMetadataManager.isBackupEnabled else {
            return
        }

        stateObservable.state = .enabled(
            syncResult,
            lastSyncDate: syncMetadataManager.getLastSyncDate()
        )
    }

    private func setupCloudSyncService(for remoteFileUrl: URL) {
        syncService = syncFactory.createSyncService(for: remoteFileUrl)

        syncService?.subscribeSyncResult(
            self,
            notifyingIn: workingQueue
        ) { [weak self] result in
            self?.mutex.lock()

            defer {
                self?.mutex.unlock()
            }

            self?.handle(syncResult: result)
        }

        syncService?.setup()
    }

    private func clearSyncService() {
        remoteMonitor?.stop()
        remoteMonitor = nil

        syncService?.stopSyncUp()
        syncService = nil
    }

    private func setupSyncServiceIfNeeded() {
        guard remoteMonitor == nil else {
            return
        }

        guard let remoteUrl = fileManager.getFileUrl() else {
            stateObservable.state = .unavailable(lastSyncDate: syncMetadataManager.getLastSyncDate())
            return
        }

        stateObservable.state = .enabled(nil, lastSyncDate: syncMetadataManager.getLastSyncDate())

        remoteMonitor = syncFactory.createRemoteUpdatesMonitor(for: remoteUrl.lastPathComponent)
        remoteMonitor?.start(notifyingIn: workingQueue) { [weak self] _ in
            self?.mutex.lock()

            defer {
                self?.mutex.unlock()
            }

            if let syncService = self?.syncService {
                syncService.syncUp()
            } else {
                self?.setupCloudSyncService(for: remoteUrl)
            }
        }
    }
}

extension CloudBackupSyncFacade: CloudBackupSyncFacadeProtocol {
    func enableBackup(
        for password: String?,
        runCompletionIn queue: DispatchQueue,
        completionClosure: @escaping (Result<Void, Error>) -> Void
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        do {
            if let password {
                try syncMetadataManager.savePassword(password)
            }

            guard !syncMetadataManager.isBackupEnabled else {
                dispatchInQueueWhenPossible(queue) {
                    completionClosure(.success(()))
                }
                return
            }

            syncMetadataManager.isBackupEnabled = true

            setupSyncServiceIfNeeded()
        } catch {
            dispatchInQueueWhenPossible(queue) {
                completionClosure(.failure(error))
            }
        }
    }

    func disableBackup(
        runCompletionIn queue: DispatchQueue,
        completionClosure: @escaping (Result<Void, Error>) -> Void
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard syncMetadataManager.isBackupEnabled else {
            dispatchInQueueWhenPossible(queue) {
                completionClosure(.success(()))
            }

            return
        }

        clearSyncService()

        stateObservable.state = .disabled(lastSyncDate: syncMetadataManager.getLastSyncDate())

        dispatchInQueueWhenPossible(queue) {
            completionClosure(.success(()))
        }
    }

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

    func setup() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard syncMetadataManager.isBackupEnabled else {
            stateObservable.state = .disabled(lastSyncDate: syncMetadataManager.getLastSyncDate())
            return
        }

        setupSyncServiceIfNeeded()
    }

    func throttle() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        clearSyncService()

        stateObservable.state = .disabled(lastSyncDate: syncMetadataManager.getLastSyncDate())
    }

    func syncUp() {
        syncService?.syncUp()
    }
}
