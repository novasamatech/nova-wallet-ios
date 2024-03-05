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
        settings: LocalPushSettings,
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
    let repository: AnyDataProviderRepository<LocalPushSettings>
    let settingsManager: SettingsManagerProtocol
    private let operationQueue: OperationQueue

    @Atomic(defaultValue: nil)
    private var executingOperationWrapper: CompoundOperationWrapper<Void>?
    private lazy var operationManager = OperationManager(operationQueue: operationQueue)

    init(
        repository: AnyDataProviderRepository<LocalPushSettings>,
        settingsManager: SettingsManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.repository = repository
        self.settingsManager = settingsManager
        self.operationQueue = operationQueue

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

        targetWrapper.targetOperation.completionBlock = { [weak self] in
            guard targetWrapper === self?.executingOperationWrapper else {
                return
            }
            self?.executingOperationWrapper = nil
            do {
                let value = try targetWrapper.targetOperation.extractNoCancellableResultData()
                self?.complete(nil)
            } catch {
                self?.complete(error)
            }
        }
    }

    private func saveWrapper(
        dependsOn fetchOperation: BaseOperation<LocalPushSettings?>,
        forceUpdate: Bool
    ) -> CompoundOperationWrapper<Void?> {
        let newSettingsOperation = ClosureOperation<LocalPushSettings?> {
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

        let wrapper: CompoundOperationWrapper<Void?> = OperationCombiningService.compoundWrapper(operationManager: operationManager) {
            guard var newSettings = try newSettingsOperation.extractNoCancellableResultData() else {
                return nil
            }
            let remoteSaveOperation = self.remoteSaveOperation(settings: newSettings)
            let localSaveOperation = self.localSaveOperation(settings: newSettings)

            let mapOperation = ClosureOperation {
                try remoteSaveOperation.extractNoCancellableResultData()
                try localSaveOperation.extractNoCancellableResultData()
            }

            mapOperation.addDependency(remoteSaveOperation)
            mapOperation.addDependency(localSaveOperation)

            return .init(targetOperation: mapOperation, dependencies: [remoteSaveOperation, localSaveOperation])
        }
        wrapper.addDependency(operations: [newSettingsOperation])
        return wrapper.insertingHead(operations: [newSettingsOperation])
    }

    override func stopSyncUp() {
        executingOperationWrapper?.cancel()
        executingOperationWrapper = nil
    }

    private func remoteSaveOperation(settings: LocalPushSettings) -> BaseOperation<Void> {
        let saveSettingsOperation: AsyncClosureOperation<Void> = AsyncClosureOperation(cancelationClosure: {}) { responseClosure in
            let database = Firestore.firestore()
            let documentRef = database.collection("users").document(settings.remoteIdentifier)
            let encoder = Firestore.Encoder()
            encoder.dateEncodingStrategy = .iso8601
            try documentRef.setData(from: RemotePushSettings(from: settings), merge: true, encoder: encoder) { error in
                if let error = error {
                    responseClosure(.failure(error))
                } else {
                    responseClosure(.success(()))
                }
            }
        }

        return saveSettingsOperation
    }

    private func localSaveOperation(settings: LocalPushSettings) -> BaseOperation<Void> {
        repository.saveOperation({
            [settings]
        }, {
            []
        })
    }

    private func fetchLocalSettingsOperation() -> BaseOperation<LocalPushSettings?> {
        guard settingsManager.notificationsEnabled else {
            return .createWithResult(nil)
        }
        return repository.fetchOperation(
            by: { LocalPushSettings.getIdentifier() },
            options: .init()
        )
    }
}

extension Web3AlertsSyncService: Web3AlertsSyncServiceProtocol {
    func save(
        settings: LocalPushSettings,
        runningInQueue queue: DispatchQueue?,
        completionHandler: @escaping (Error?) -> Void
    ) {
        let remoteSaveOperation = remoteSaveOperation(settings: settings)
        let localSaveOperation = localSaveOperation(settings: settings)
        localSaveOperation.addDependency(remoteSaveOperation)

        let mapOperation = ClosureOperation {
            do {
                _ = try localSaveOperation.extractNoCancellableResultData()
                dispatchInQueueWhenPossible(queue) {
                    completionHandler(nil)
                }
            } catch {
                dispatchInQueueWhenPossible(queue) {
                    completionHandler(error)
                }
            }
        }
        if let executingOperationWrapper = executingOperationWrapper {
            mapOperation.addDependency(executingOperationWrapper.targetOperation)
        }

        mapOperation.addDependency(localSaveOperation)
        operationQueue.addOperations([remoteSaveOperation, localSaveOperation, mapOperation], waitUntilFinished: false)
    }

    func update(
        token: String,
        runningInQueue queue: DispatchQueue?,
        completionHandler: @escaping () -> Void
    ) {
        guard settingsManager.notificationsEnabled else {
            dispatchInQueueWhenPossible(queue, block: completionHandler)
            return
        }
        let fetchOperation = repository.fetchOperation(by: { LocalPushSettings.getIdentifier() }, options: .init())
        let updateSettingsOperation: BaseOperation<LocalPushSettings?> = ClosureOperation {
            if var localSettings = try fetchOperation.extractNoCancellableResultData() {
                localSettings.pushToken = token
                localSettings.updatedAt = Date()
                return localSettings
            } else {
                return nil
            }
        }
        updateSettingsOperation.addDependency(fetchOperation)

        let wrapper = saveWrapper(dependsOn: updateSettingsOperation, forceUpdate: true)
        wrapper.addDependency(operations: [fetchOperation, updateSettingsOperation])

        let updatingWrapper = wrapper.insertingHead(operations: [fetchOperation, updateSettingsOperation])

        updatingWrapper.targetOperation.completionBlock = {
            dispatchInQueueWhenPossible(queue, block: completionHandler)
        }

        executingOperationWrapper.map {
            updatingWrapper.addDependency(wrapper: $0)
        }

        operationQueue.addOperations(updatingWrapper.allOperations, waitUntilFinished: false)
    }
}
