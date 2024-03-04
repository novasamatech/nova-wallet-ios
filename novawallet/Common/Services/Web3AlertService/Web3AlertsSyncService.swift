import RobinHood
import SoraFoundation
import SoraKeystore
import FirebaseCore
import FirebaseFirestore
import FirebaseMessaging

enum Web3AlertsSyncServiceError: Error {
    case notificationsDisabled
}

protocol Web3AlertsSyncServiceProtocol: ApplicationServiceProtocol {
    func save(
        settings: Web3Alert.LocalSettings,
        runningInQueue: DispatchQueue?,
        completionHandler: @escaping (Error?) -> Void
    )

    func update(
        token: String,
        runningInQueue: DispatchQueue?,
        completionHandler: @escaping () -> Void
    )
}

final class Web3AlertsSyncService: BaseSyncService {
    let repository: AnyDataProviderRepository<Web3Alert.LocalSettings>
    let settingsManager: SettingsManagerProtocol
    private let operationQueue: OperationQueue
    private let workQueue: DispatchQueue

    private var syncWrapperStore = CancellableCallStore()

    private var executingOperationWrapper: CompoundOperationWrapper<Void>? {
        syncWrapperStore.getCall()
    }

    private lazy var operationManager = OperationManager(operationQueue: operationQueue)

    init(
        repository: AnyDataProviderRepository<Web3Alert.LocalSettings>,
        settingsManager: SettingsManagerProtocol,
        operationQueue: OperationQueue,
        workQueue: DispatchQueue = .global()
    ) {
        self.repository = repository
        self.settingsManager = settingsManager
        self.operationQueue = operationQueue
        self.workQueue = workQueue

        FirebaseHolder.shared.configureApp()
    }

    override func performSyncUp() {
        guard executingOperationWrapper == nil else {
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
            guard var localSettings = try fetchOperation.extractNoCancellableResultData() else {
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
            localSettings.updatedAt = now
            return localSettings
        }

        newSettingsOperation.addDependency(fetchOperation)

        let wrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: operationManager
        ) {
            guard var newSettings = try newSettingsOperation.extractNoCancellableResultData() else {
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
        let saveSettingsOperation: AsyncClosureOperation<Void> = AsyncClosureOperation(
            cancelationClosure: {}
        ) { responseClosure in
            let database = Firestore.firestore()
            let documentRef = database.collection("users").document(settings.remoteIdentifier)
            let encoder = Firestore.Encoder()
            encoder.dateEncodingStrategy = .iso8601
            try documentRef.setData(
                from: Web3Alert.RemoteSettings(from: settings),
                merge: true,
                encoder: encoder
            ) { error in
                if let error = error {
                    responseClosure(.failure(error))
                } else {
                    responseClosure(.success(()))
                }
            }
        }

        return saveSettingsOperation
    }

    private func localSaveOperation(settings: Web3Alert.LocalSettings) -> BaseOperation<Void> {
        repository.saveOperation({
            [settings]
        }, {
            []
        })
    }

    private func fetchLocalSettingsOperation() -> BaseOperation<Web3Alert.LocalSettings?> {
        // TODO: This is not obvious. Probably not run the service if notifications disabled
        guard settingsManager.notificationsEnabled else {
            return .createWithResult(nil)
        }

        return repository.fetchOperation(
            by: { Web3Alert.LocalSettings.getIdentifier() },
            options: .init()
        )
    }
}

extension Web3AlertsSyncService: Web3AlertsSyncServiceProtocol {
    func save(
        settings: Web3Alert.LocalSettings,
        runningInQueue queue: DispatchQueue?,
        completionHandler: @escaping (Error?) -> Void
    ) {
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

        if let executingOperationWrapper = executingOperationWrapper {
            wrapper.addDependency(wrapper: executingOperationWrapper)
        }

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: queue
        ) { [weak self] result in
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

    func update(
        token: String,
        runningInQueue queue: DispatchQueue?,
        completionHandler: @escaping () -> Void
    ) {
        // TODO: This is not obvious. Probably not run the service if notifications disabled
        guard settingsManager.notificationsEnabled else {
            dispatchInQueueWhenPossible(queue, block: completionHandler)
            return
        }
        let fetchOperation = repository.fetchOperation(
            by: { Web3Alert.LocalSettings.getIdentifier() },
            options: .init()
        )

        let updateSettingsOperation: BaseOperation<Web3Alert.LocalSettings?> = ClosureOperation {
            if var localSettings = try fetchOperation.extractNoCancellableResultData() {
                localSettings.pushToken = token
                localSettings.updatedAt = Date()
                return localSettings
            } else {
                return nil
            }
        }

        updateSettingsOperation.addDependency(fetchOperation)

        let saveWrapper = saveWrapper(dependsOn: updateSettingsOperation, forceUpdate: true)
        saveWrapper.addDependency(operations: [fetchOperation, updateSettingsOperation])

        let updatingWrapper = saveWrapper.insertingHead(operations: [fetchOperation, updateSettingsOperation])

        if let executingOperationWrapper = executingOperationWrapper {
            updatingWrapper.addDependency(wrapper: executingOperationWrapper)
        }

        execute(
            wrapper: updatingWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: queue
        ) { [weak self] result in
            switch result {
            case .success:
                self?.logger.debug("Web3 Alert token updated")
            case let .failure(error):
                self?.logger.error("Web3 Alert token updated failed: \(error)")
            }

            completionHandler()
        }
    }
}
