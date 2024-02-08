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
                let uuid = self.settingsManager.pushSettingsDocumentId ?? ""
                return .createDefault(uuid: uuid)
            }
            guard !forceUpdate else {
                return localSettings
            }
            let updatedMoreThanDayAgo = (Date() - localSettings.updatedAt).seconds >= 0
            guard updatedMoreThanDayAgo else {
                return nil
            }
            localSettings.updatedAt = Date()
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
        guard let documentUUID = settingsManager.pushSettingsDocumentId else {
            return .createWithError(Web3AlertsSyncServiceError.documentNotFound)
        }

        let saveSettingsOperation: AsyncClosureOperation<Void> = AsyncClosureOperation(cancelationClosure: {}) { responseClosure in
            let database = Firestore.firestore()
            let documentRef = database.collection("users").document(documentUUID)
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
        let savingSettings: LocalPushSettings

        if settings.identifier.isEmpty {
            let uuid = UUID().uuidString
            savingSettings = .init(
                identifier: uuid,
                pushToken: settings.pushToken,
                updatedAt: settings.updatedAt,
                wallets: settings.wallets,
                notifications: settings.notifications
            )
        } else {
            savingSettings = settings
        }
        settingsManager.pushSettingsDocumentId = savingSettings.identifier
        let localSaveOperation = localSaveOperation(settings: savingSettings)

        return localSaveOperation
    }

    func update(token: String) -> CompoundOperationWrapper<Void?> {
        guard let documentUUID = settingsManager.pushSettingsDocumentId else {
            return .createWithError(Web3AlertsSyncServiceError.documentNotFound)
        }

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

extension Date {
    static func - (lhs: Date, rhs: Date) -> TimeInterval {
        lhs.timeIntervalSinceReferenceDate - rhs.timeIntervalSinceReferenceDate
    }
}
