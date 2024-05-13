import Foundation
import SoraKeystore
import SubstrateSdk
import RobinHood

protocol CloudBackupSyncServiceProtocol: SyncServiceProtocol {
    func subscribeSyncResult(
        _ object: AnyObject,
        notifyingIn queue: DispatchQueue,
        closure: @escaping (CloudBackupSyncResult) -> Void
    )

    func unsubscribeSyncResult(_ object: AnyObject)
}

final class CloudBackupSyncService: BaseSyncService, AnyCancellableCleaning {
    let updateCalculationFactory: CloudBackupUpdateCalculationFactoryProtocol
    let remoteFileUrl: URL

    let workingQueue: DispatchQueue
    let operationQueue: OperationQueue

    private var syncObservable: Observable<CloudBackupSyncResult> = .init(state: .noUpdates)

    private var cancellableStore = CancellableCallStore()

    init(
        remoteFileUrl: URL,
        updateCalculationFactory: CloudBackupUpdateCalculationFactoryProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue = DispatchQueue.global(),
        retryStrategy: ReconnectionStrategyProtocol = ExponentialReconnection(),
        logger: LoggerProtocol = Logger.shared
    ) {
        self.remoteFileUrl = remoteFileUrl
        self.updateCalculationFactory = updateCalculationFactory
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue

        super.init(retryStrategy: retryStrategy, logger: logger)
    }

    override func performSyncUp() {
        let updateCalculationWrapper = updateCalculationFactory.createUpdateCalculation(for: remoteFileUrl)

        executeCancellable(
            wrapper: updateCalculationWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: cancellableStore,
            runningCallbackIn: workingQueue,
            mutex: mutex
        ) { [weak self] result in
            switch result {
            case let .success(update):
                self?.logger.debug("Backup sync update: \(update)")
                self?.syncObservable.state = update
                self?.completeImmediate(nil)
            case let .failure(error):
                self?.completeImmediate(error)
            }
        }
    }

    override func stopSyncUp() {
        cancellableStore.cancel()
    }
}

extension CloudBackupSyncService: CloudBackupSyncServiceProtocol {
    func subscribeSyncResult(
        _ object: AnyObject,
        notifyingIn queue: DispatchQueue,
        closure: @escaping (CloudBackupSyncResult) -> Void
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        syncObservable.addObserver(
            with: object,
            sendStateOnSubscription: true,
            queue: queue
        ) { _, newState in
            closure(newState)
        }
    }

    func unsubscribeSyncResult(_ object: AnyObject) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        syncObservable.removeObserver(by: object)
    }
}
