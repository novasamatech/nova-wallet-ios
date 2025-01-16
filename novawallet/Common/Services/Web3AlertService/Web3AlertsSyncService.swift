import Operation_iOS
import Foundation_iOS
import Keystore_iOS
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

    func updateWallets(
        dependingOn localWalletClosure: @escaping () throws -> [MetaAccountModel.Id: MetaAccountModel],
        chainsClosure: @escaping () throws -> [ChainModel.Id: ChainModel],
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
        AsyncClosureOperation { responseClosure in
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
    }

    private func remoteDeleteOperation(
        for remoteIdentifier: String
    ) -> BaseOperation<Void> {
        AsyncClosureOperation { responseClosure in
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

    private func syncedExecute<T>(
        wrapper: CompoundOperationWrapper<T>,
        callbackQueue: DispatchQueue,
        mutex: NSLock,
        callStore: CancellableCallStore,
        callbackClosure: @escaping (Result<T, Error>) -> Void
    ) {
        wrapper.targetOperation.completionBlock = {
            dispatchInQueueWhenPossible(callbackQueue, locking: mutex) {
                // still deliver result for current even executing other wrapper
                _ = callStore.clearIfMatches(call: wrapper)

                do {
                    let value = try wrapper.targetOperation.extractNoCancellableResultData()
                    callbackClosure(.success(value))
                } catch {
                    callbackClosure(.failure(error))
                }
            }
        }

        callStore.store(call: wrapper)

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    private func createWalletsDiffWrapper(
        dependingOn localWalletClosure: @escaping () throws -> [MetaAccountModel.Id: MetaAccountModel],
        chainsClosure: @escaping () throws -> [ChainModel.Id: ChainModel]
    ) -> CompoundOperationWrapper<Web3Alert.LocalSettings?> {
        let fetchLocalSettingsOperation = fetchLocalSettingsOperation()

        let newLocalSettingsOperation = ClosureOperation<Web3Alert.LocalSettings?> {
            guard let localSettings = try fetchLocalSettingsOperation.extractNoCancellableResultData() else {
                return nil
            }

            let localWallets = try localWalletClosure()
            let chains = try chainsClosure()

            let settingsFactory = PushNotificationSettingsFactory()

            let existingRemoteWallets: [Web3Alert.LocalWallet] = localSettings.wallets.compactMap { remoteWallet in
                guard let localWallet = localWallets[remoteWallet.metaId] else {
                    return nil
                }

                return settingsFactory.createWallet(from: localWallet, chains: chains)
            }

            if existingRemoteWallets != localSettings.wallets {
                return localSettings.with(wallets: existingRemoteWallets)
            } else {
                return nil
            }
        }

        newLocalSettingsOperation.addDependency(fetchLocalSettingsOperation)

        return CompoundOperationWrapper(
            targetOperation: newLocalSettingsOperation,
            dependencies: [fetchLocalSettingsOperation]
        )
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

        syncedExecute(
            wrapper: wrapper,
            callbackQueue: workQueue,
            mutex: mutex,
            callStore: syncWrapperStore
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

        syncedExecute(
            wrapper: updatingWrapper,
            callbackQueue: workQueue,
            mutex: mutex,
            callStore: syncWrapperStore
        ) { [weak self] result in
            dispatchInQueueWhenPossible(queue) {
                switch result {
                case .success:
                    let tokenChanged = (try? updateSettingsOperation.extractNoCancellableResultData()) != nil

                    if tokenChanged {
                        self?.logger.debug("Web3 Alert push token updated")
                    } else {
                        self?.logger.debug("Web3 Alert push token not changed")
                    }
                case let .failure(error):
                    self?.logger.error("Web3 Alert push token updated failed: \(error)")
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

        syncedExecute(
            wrapper: wrapper,
            callbackQueue: workQueue,
            mutex: mutex,
            callStore: syncWrapperStore
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

    func updateWallets(
        dependingOn localWalletClosure: @escaping () throws -> [MetaAccountModel.Id: MetaAccountModel],
        chainsClosure: @escaping () throws -> [ChainModel.Id: ChainModel],
        runningIn queue: DispatchQueue?,
        completionHandler: @escaping (Error?) -> Void
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        logger.debug("Updating wallets...")

        let walletsDiffWrapper = createWalletsDiffWrapper(
            dependingOn: localWalletClosure,
            chainsClosure: chainsClosure
        )

        let saveWrapper = saveWrapper(dependsOn: walletsDiffWrapper.targetOperation, forceUpdate: true)

        saveWrapper.addDependency(wrapper: walletsDiffWrapper)

        let wrapper = saveWrapper.insertingHead(operations: walletsDiffWrapper.allOperations)

        waitInProgress(for: wrapper)

        syncedExecute(
            wrapper: wrapper,
            callbackQueue: workQueue,
            mutex: mutex,
            callStore: syncWrapperStore
        ) { [weak self] result in
            dispatchInQueueWhenPossible(queue) {
                switch result {
                case .success:
                    if let settings = try? walletsDiffWrapper.targetOperation.extractNoCancellableResultData() {
                        self?.logger.debug("New wallets: \(settings.wallets)")
                    } else {
                        self?.logger.debug("No wallet changes")
                    }

                    completionHandler(nil)
                case let .failure(error):
                    completionHandler(error)
                }
            }
        }
    }
}
