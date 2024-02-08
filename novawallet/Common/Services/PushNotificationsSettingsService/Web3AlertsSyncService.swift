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
    func configure()
    func save(settings: LocalPushSettings) -> CompoundOperationWrapper<Void>
    func getLastSettings() -> BaseOperation<LocalPushSettings?>
    func update(token: String) -> CompoundOperationWrapper<Void>
    func subscribe(to topic: NotificationTopic)
    func unsubscribe(from topic: NotificationTopic)
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
        let remoteSettingsOperation = fetchRemoteSettingsOperation()
        let localSettingsOperation = fetchLocalSettingsOperation()

        let wrapper = OperationCombiningService.compoundWrapper(operationManager: operationManager) {
            let remoteSettings = try remoteSettingsOperation.extractNoCancellableResultData()
            let localSettings = try localSettingsOperation.extractNoCancellableResultData()
            let saveOperation = self.saveWrapper(localSettings: localSettings, remoteSettings: remoteSettings)
            return .init(targetOperation: saveOperation)
        }

        wrapper.addDependency(operations: [remoteSettingsOperation, localSettingsOperation])

        executeCancellable(
            wrapper: wrapper,
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
        localSettings: LocalPushSettings?,
        remoteSettings: LocalPushSettings?
    ) -> BaseOperation<Void> {
        if let localSettings = localSettings {
            if let remoteSettings = remoteSettings, localSettings.updatedAt > remoteSettings.updatedAt {
                return localSaveOperation(settings: remoteSettings)
            } else {
                return remoteSaveOperation(settings: localSettings)
            }
        } else if let remoteSettings = remoteSettings {
            return localSaveOperation(settings: remoteSettings)
        } else {
            return .createWithError(CommonError.undefined)
        }
    }

    override func stopSyncUp() {
        syncCancellable.cancel()
    }

    private func fetchRemoteSettingsOperation() -> BaseOperation<LocalPushSettings?> {
        guard let documentUUID = settingsManager.pushSettingsDocumentId else {
            return .createWithResult(nil)
        }

        let fetchSettingsOperation: AsyncClosureOperation<LocalPushSettings?> = AsyncClosureOperation(cancelationClosure: {}) { responseClosure in
            let database = Firestore.firestore()
            let documentRef = database.collection("users").document(documentUUID)

            documentRef.getDocument(as: RemotePushSettings.self) { result in
                switch result {
                case let .success(settings):
                    responseClosure(.success(.init(from: settings, identifier: documentUUID)))
                case let .failure(error):
                    responseClosure(.failure(error))
                }
            }
        }

        return fetchSettingsOperation
    }

    private func remoteSaveOperation(settings: LocalPushSettings) -> BaseOperation<Void> {
        guard let documentUUID = settingsManager.pushSettingsDocumentId else {
            return .createWithError(Web3AlertsSyncServiceError.documentNotFound)
        }

        let saveSettingsOperation: AsyncClosureOperation<Void> = AsyncClosureOperation(cancelationClosure: {}) { responseClosure in
            let database = Firestore.firestore()
            let documentRef = database.collection("users").document(documentUUID)
            try documentRef.setData(from: RemotePushSettings(from: settings), merge: true) { error in
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
        repository.replaceOperation {
            [settings]
        }
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

    private func subscribe(channel: String) {
        Messaging.messaging().subscribe(toTopic: channel) { [weak self] error in
            if let error = error {
                self?.logger.error(error.localizedDescription)
            }
        }
    }

    private func unsubscribe(channel: String) {
        Messaging.messaging().unsubscribe(fromTopic: channel) { [weak self] error in
            if let error = error {
                self?.logger.error(error.localizedDescription)
            }
        }
    }
}

extension Web3AlertsSyncService: Web3AlertsSyncServiceProtocol {
    func configure() {
        FirebaseApp.configure()
    }

    func getLastSettings() -> BaseOperation<LocalPushSettings?> {
        fetchLocalSettingsOperation()
    }

    func save(settings: LocalPushSettings) -> CompoundOperationWrapper<Void> {
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
        let remoteSaveOperation = remoteSaveOperation(settings: savingSettings)
        remoteSaveOperation.addDependency(localSaveOperation)
        return .init(targetOperation: remoteSaveOperation, dependencies: [localSaveOperation])
    }

    func update(token: String) -> CompoundOperationWrapper<Void> {
        guard let documentUUID = settingsManager.pushSettingsDocumentId else {
            return save(settings: .createDefault(for: token))
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

        return .init(targetOperation: updateOperation, dependencies: [fetchOperation])
    }

    func subscribe(to topic: NotificationTopic) {
        subscribe(channel: topic.identifier)
    }

    func unsubscribe(from topic: NotificationTopic) {
        unsubscribe(channel: topic.identifier)
    }
}
