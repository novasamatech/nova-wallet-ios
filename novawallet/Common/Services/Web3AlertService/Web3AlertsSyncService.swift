import RobinHood
import SoraFoundation
import SoraKeystore
import FirebaseCore
import FirebaseFirestore
import FirebaseMessaging

protocol Web3AlertsSyncServiceProtocol: ApplicationServiceProtocol {
    func save(
        settings: Web3Alert.LocalSettings,
        runningIn queue: DispatchQueue?,
        completionHandler: @escaping (Error?) -> Void
    )

    func update(
        token: String,
        runningIn queue: DispatchQueue?,
        completionHandler: @escaping () -> Void
    )

    func disableRemote(
        settings: Web3Alert.LocalSettings,
        runningIn queue: DispatchQueue?,
        completionHandler: @escaping (Error?) -> Void
    )
}

final class Web3AlertsSyncService: BaseSyncService {
    let repository: AnyDataProviderRepository<Web3Alert.LocalSettings>
    private let operationQueue: OperationQueue
    private let workQueue: DispatchQueue

    private var syncWrapperStore = CancellableCallStore()

    private lazy var operationManager = OperationManager(operationQueue: operationQueue)

    init(
        repository: AnyDataProviderRepository<Web3Alert.LocalSettings>,
        operationQueue: OperationQueue,
        workQueue: DispatchQueue = .global()
    ) {
        self.repository = repository
        self.operationQueue = operationQueue
        self.workQueue = workQueue
    }

    override func performSyncUp() {
        guard !syncWrapperStore.hasCall else {
            logger.debug("Sync already in progress")
            completeImmediate(nil)
            return
        }

        let localSettingsOperation = fetchLocalSettingsOperation()
        let wrapper = saveWrapper(dependsOn: localSettingsOperation, forceUpdate: false)
        wrapper.addDependency(operations: [localSettingsOperation])

        let targetWrapper = wrapper.insertingHead(operations: [localSettingsOperation])

        executeCancellable(
            wrapper: targetWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: syncWrapperStore,
            runningCallbackIn: workQueue,
            mutex: mutex
        ) { [weak self] result in
            switch result {
            case .success:
                self?.logger.debug("Web3 Alert sync completed")
                self?.completeImmediate(nil)
            case let .failure(error):
                self?.completeImmediate(error)
            }
        }
    }

    private func saveWrapper(
        dependsOn fetchOperation: BaseOperation<Web3Alert.LocalSettings?>,
        forceUpdate: Bool
    ) -> CompoundOperationWrapper<Void> {
        let newSettingsOperation = ClosureOperation<Web3Alert.LocalSettings?> {
            guard let localSettings = try fetchOperation.extractNoCancellableResultData() else {
                return nil
            }
            guard !forceUpdate else {
                return localSettings
            }
            let now = Date()
            let lastUpdate = now.timeIntervalSinceReferenceDate - localSettings.updatedAt.timeIntervalSinceReferenceDate
            if lastUpdate.daysFromSeconds < 1 {
                return nil
            }

            return localSettings.updating(date: now)
        }

        newSettingsOperation.addDependency(fetchOperation)

        let wrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: operationManager
        ) {
            guard let newSettings = try newSettingsOperation.extractNoCancellableResultData() else {
                return CompoundOperationWrapper.createWithResult(())
            }

            let remoteSaveOperation = self.remoteSaveOperation(settings: newSettings)
            let localSaveOperation = self.localSaveOperation(settings: newSettings)

            localSaveOperation.configurationBlock = {
                do {
                    try remoteSaveOperation.extractNoCancellableResultData()
                } catch {
                    localSaveOperation.result = .failure(error)
                }
            }

            localSaveOperation.addDependency(remoteSaveOperation)

            return CompoundOperationWrapper(
                targetOperation: localSaveOperation,
                dependencies: [remoteSaveOperation]
            )
        }

        wrapper.addDependency(operations: [newSettingsOperation])

        return wrapper.insertingHead(operations: [newSettingsOperation])
    }

    override func stopSyncUp() {
        syncWrapperStore.cancel()
    }

    private func remoteSaveOperation(
        settings: Web3Alert.LocalSettings
    ) -> BaseOperation<Void> {
        AsyncClosureOperation(
            cancelationClosure: {},
            operationClosure: { responseClosure in
                let database = Firestore.firestore()
                let documentRef = database.collection("users").document(settings.remoteIdentifier)
                let encoder = Firestore.Encoder()
                encoder.dateEncodingStrategy = .iso8601
                try documentRef.setData(
                    from: Web3Alert.RemoteSettings(from: settings),
                    merge: false,
                    encoder: encoder
                ) { error in
                    if let error = error {
                        responseClosure(.failure(error))
                    } else {
                        responseClosure(.success(()))
                    }
                }
            }
        )
    }

    private func remoteDeleteOperation(
        for remoteIdentifier: String
    ) -> BaseOperation<Void> {
        AsyncClosureOperation(
            cancelationClosure: {},
            operationClosure: { responseClosure in
                let database = Firestore.firestore()
                let documentRef = database.collection("users").document(remoteIdentifier)

                documentRef.delete { optError in
                    if let error = optError {
                        responseClosure(.failure(error))
                    } else {
                        responseClosure(.success(()))
                    }
                }
            }
        )
    }

    private func localSaveOperation(settings: Web3Alert.LocalSettings) -> BaseOperation<Void> {
        repository.saveOperation({
            [settings]
        }, {
            []
        })
    }

    private func fetchLocalSettingsOperation() -> BaseOperation<Web3Alert.LocalSettings?> {
        repository.fetchOperation(
            by: { Web3Alert.LocalSettings.getIdentifier() },
            options: .init()
        )
    }

    private func waitInProgress(for wrapper: CompoundOperationWrapper<Void>) {
        if let executingCall = syncWrapperStore.operatingCall {
            logger.debug("Waiting previous call")
            wrapper.addDependency(operations: executingCall.allOperations)
        }
    }
}

extension Web3AlertsSyncService: Web3AlertsSyncServiceProtocol {
    func save(
        settings: Web3Alert.LocalSettings,
        runningIn queue: DispatchQueue?,
        completionHandler: @escaping (Error?) -> Void
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        logger.debug("Saving push settings...")

        let remoteSaveOperation = remoteSaveOperation(settings: settings)

        let localSaveOperation = localSaveOperation(settings: settings)

        localSaveOperation.configurationBlock = {
            do {
                try remoteSaveOperation.extractNoCancellableResultData()
            } catch {
                localSaveOperation.result = .failure(error)
            }
        }

        localSaveOperation.addDependency(remoteSaveOperation)

        let wrapper = CompoundOperationWrapper(targetOperation: localSaveOperation, dependencies: [remoteSaveOperation])

        waitInProgress(for: wrapper)

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: syncWrapperStore,
            runningCallbackIn: workQueue,
            mutex: mutex
        ) { [weak self] result in
            dispatchInQueueWhenPossible(queue) {
                switch result {
                case .success:
                    self?.logger.debug("Web3 Alert settings saved")
                    completionHandler(nil)
                case let .failure(error):
                    self?.logger.debug("Web3 Alert settings save failed: \(error)")
                    completionHandler(error)
                }
            }
        }
    }

    func update(
        token: String,
        runningIn queue: DispatchQueue?,
        completionHandler: @escaping () -> Void
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        logger.debug("Updating push token...")

        let fetchOperation = repository.fetchOperation(
            by: { Web3Alert.LocalSettings.getIdentifier() },
            options: .init()
        )

        let updateSettingsOperation: BaseOperation<Web3Alert.LocalSettings?> = ClosureOperation {
            if
                let localSettings = try fetchOperation.extractNoCancellableResultData(),
                localSettings.pushToken != token {
                return localSettings
                    .updating(pushToken: token)
                    .settingCurrentDate()
            } else {
                return nil
            }
        }

        updateSettingsOperation.addDependency(fetchOperation)

        let saveWrapper = saveWrapper(dependsOn: updateSettingsOperation, forceUpdate: true)
        saveWrapper.addDependency(operations: [fetchOperation, updateSettingsOperation])

        let updatingWrapper = saveWrapper.insertingHead(operations: [fetchOperation, updateSettingsOperation])

        waitInProgress(for: updatingWrapper)

        executeCancellable(
            wrapper: updatingWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: syncWrapperStore,
            runningCallbackIn: workQueue,
            mutex: mutex
        ) { [weak self] result in
            dispatchInQueueWhenPossible(queue) {
                switch result {
                case .success:
                    let tokenChanged = (try? updateSettingsOperation.extractNoCancellableResultData()) != nil

                    if tokenChanged {
                        self?.logger.debug("Web3 Alert token updated")
                    } else {
                        self?.logger.debug("Web3 Alert token not changed")
                    }
                case let .failure(error):
                    self?.logger.error("Web3 Alert token updated failed: \(error)")
                }

                completionHandler()
            }
        }
    }

    func disableRemote(
        settings: Web3Alert.LocalSettings,
        runningIn queue: DispatchQueue?,
        completionHandler: @escaping (Error?) -> Void
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        logger.debug("Deleting remote settings...")

        let remoteDeleteOperation = remoteDeleteOperation(for: settings.remoteIdentifier)

        let localSaveOperation = localSaveOperation(settings: settings)

        localSaveOperation.configurationBlock = {
            do {
                try remoteDeleteOperation.extractNoCancellableResultData()
            } catch {
                localSaveOperation.result = .failure(error)
            }
        }

        localSaveOperation.addDependency(remoteDeleteOperation)

        let wrapper = CompoundOperationWrapper(
            targetOperation: localSaveOperation,
            dependencies: [remoteDeleteOperation]
        )

        waitInProgress(for: wrapper)

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: syncWrapperStore,
            runningCallbackIn: workQueue,
            mutex: mutex
        ) { [weak self] result in
            dispatchInQueueWhenPossible(queue) {
                switch result {
                case .success:
                    self?.logger.debug("Web3 Alert settings removed")
                    completionHandler(nil)
                case let .failure(error):
                    self?.logger.debug("Web3 Alert settings remove failed: \(error)")
                    completionHandler(error)
                }
            }
        }
    }
}
