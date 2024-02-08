import RobinHood
import SoraFoundation
import SoraKeystore
import FirebaseCore
import FirebaseFirestore
import FirebaseMessaging

enum Web3AlertsSyncServiceError: Error {
    case documentNotFound
}

protocol Web3AlertsSyncServiceProtocol: ApplicationServiceProtocol {
    func save(settings: LocalPushSettings) -> BaseOperation<Void>
    func update(token: String) -> CompoundOperationWrapper<Void?>
}

final class Web3AlertsSyncService: BaseSyncService {
    let repository: AnyDataProviderRepository<LocalPushSettings>
    let settingsManager: SettingsManagerProtocol
    private let operationQueue: OperationQueue
    private let workingQueue: DispatchQueue
    private var syncCancellable = CancellableCallStore()

    private lazy var operationManager = OperationManager(operationQueue: operationQueue)

    init(
        repository: AnyDataProviderRepository<LocalPushSettings>,
        settingsManager: SettingsManagerProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue = .global()
    ) {
        self.repository = repository
        self.settingsManager = settingsManager
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue
    }

    override func performSyncUp() {
        FirebaseHolder.shared.configureApp()

        let localSettingsOperation = fetchLocalSettingsOperation()
        let wrapper = saveWrapper(dependsOn: localSettingsOperation, forceUpdate: false)
        wrapper.addDependency(operations: [localSettingsOperation])
        let targetWrapper = wrapper.insertingHead(operations: [localSettingsOperation])

        executeCancellable(
            wrapper: targetWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: syncCancellable,
            runningCallbackIn: workingQueue
        ) { [weak self] result in
            switch result {
            case let .success:
                self?.complete(nil)
            case let .failure(error):
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
        syncCancellable.cancel()
    }

    private func remoteSaveOperation(settings: LocalPushSettings) -> BaseOperation<Void> {
        let saveSettingsOperation: AsyncClosureOperation<Void> = AsyncClosureOperation(cancelationClosure: {}) { responseClosure in
            let database = Firestore.firestore()
            let documentRef = database.collection("users").document(settings.identifier)
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
        guard let documentUUID = settingsManager.pushSettingsDocumentId else {
            return .createWithResult(nil)
        }
        return repository.fetchOperation(
            by: { documentUUID },
            options: .init()
        )
    }
}

extension Web3AlertsSyncService: Web3AlertsSyncServiceProtocol {
    func save(settings: LocalPushSettings) -> BaseOperation<Void> {
        FirebaseHolder.shared.configureApp()
        settingsManager.pushSettingsDocumentId = settings.identifier
        return localSaveOperation(settings: settings)
    }

    func update(token: String) -> CompoundOperationWrapper<Void?> {
        guard let documentUUID = settingsManager.pushSettingsDocumentId else {
            return .createWithError(Web3AlertsSyncServiceError.documentNotFound)
        }

        FirebaseHolder.shared.configureApp()
        let fetchOperation = repository.fetchOperation(by: { documentUUID }, options: .init())
        let updateOperation = repository.saveOperation({
            if var localSettings = try fetchOperation.extractNoCancellableResultData() {
                localSettings.pushToken = token
                localSettings.updatedAt = Date()
                return [localSettings]
            } else {
                return []
            }
        }, { [] })
        updateOperation.addDependency(fetchOperation)

        let fetchNewSettingsOperation = repository.fetchOperation(by: { documentUUID }, options: .init())
        fetchNewSettingsOperation.addDependency(updateOperation)

        let wrapper = saveWrapper(dependsOn: fetchNewSettingsOperation, forceUpdate: true)
        wrapper.addDependency(operations: [updateOperation, fetchNewSettingsOperation])

        return wrapper.insertingHead(operations: [updateOperation, fetchNewSettingsOperation])
    }
}
