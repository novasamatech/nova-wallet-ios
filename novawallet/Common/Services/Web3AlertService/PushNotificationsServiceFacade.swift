import Foundation
import Operation_iOS
import Keystore_iOS

enum PushNotificationsServiceFacadeError: Error {
    case serviceUnvailable(String)
    case settingsUpdateFailed(Error)
}

protocol PushNotificationsServiceFacadeProtocol: ApplicationServiceProtocol {
    func save(
        settings: PushNotification.AllSettings,
        completion: @escaping (Result<Void, PushNotificationsServiceFacadeError>) -> Void
    )

    func subscribeStatus(
        _ target: AnyObject,
        closure: @escaping (PushNotificationsStatus, PushNotificationsStatus) -> Void
    )

    func unsubscribeStatus(_ target: AnyObject)

    func updateAPNS(token: Data)

    func syncWallets()
}

final class PushNotificationsServiceFacade {
    static let shared = PushNotificationsServiceFacade(
        factory: PushNotificationsFacadeFactory(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            storageFacade: UserDataStorageFacade.shared,
            settingsManager: SettingsManager.shared,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        ),
        operationQueue: OperationManagerFacade.sharedDefaultQueue,
        logger: Logger.shared
    )

    let factory: PushNotificationsFacadeFactoryProtocol
    let operationQueue: OperationQueue
    let setupTimeoutInSec: Int
    let logger: LoggerProtocol

    let statusService: PushNotificationsStatusServiceProtocol

    private(set) var syncService: Web3AlertsSyncServiceProtocol?
    private(set) var topicService: PushNotificationsTopicServiceProtocol?
    private(set) var walletsUpdateService: SyncServiceProtocol?

    private var isActive: Bool = false

    init(
        factory: PushNotificationsFacadeFactoryProtocol,
        operationQueue: OperationQueue,
        setupTimeoutInSec: Int = 30,
        logger: LoggerProtocol
    ) {
        self.factory = factory
        self.operationQueue = operationQueue
        self.setupTimeoutInSec = setupTimeoutInSec
        self.logger = logger

        statusService = factory.createStatusService()
    }

    private func subscribeStatus() {
        processStatusChange(for: .unknown, newStatus: statusService.statusObservable.state)

        statusService.statusObservable.addObserver(with: self) { [weak self] oldStatus, newStatus in
            dispatchInQueueWhenPossible(.main) {
                self?.processStatusChange(for: oldStatus, newStatus: newStatus)
            }
        }
    }

    private func refreshPushTokenIfNeeded() {
        if let currentToken = statusService.getToken() {
            updateWeb3PushToken(using: currentToken)
        }
    }

    private func processStatusChange(for oldStatus: PushNotificationsStatus, newStatus: PushNotificationsStatus) {
        guard isActive else {
            return
        }

        if oldStatus != .active, newStatus == .active {
            logger.debug("Activating push notifications")

            setupServicesForActiveStateIfNeeded()

            statusService.register()

            refreshPushTokenIfNeeded()
        }

        if oldStatus == .active, newStatus != .active {
            logger.debug("Deactivating push notifications")

            throttleServicesIfNeeded()
        }
    }

    private func setupServicesForActiveStateIfNeeded() {
        FirebaseHolder.shared.configureApp()

        if syncService == nil {
            syncService = factory.createSyncService()
            syncService?.setup()
        }

        if topicService == nil {
            topicService = factory.createTopicService()
        }

        if let web3SyncService = syncService, walletsUpdateService == nil {
            walletsUpdateService = factory.createWalletsUpdateService(
                for: web3SyncService
            )

            walletsUpdateService?.setup()
        }
    }

    private func throttleServicesIfNeeded() {
        syncService?.throttle()
        syncService = nil

        topicService = nil
    }

    private func createAccountBasedUpdate(
        from settings: PushNotification.AllSettings,
        syncService: Web3AlertsSyncServiceProtocol
    ) -> BaseOperation<Void> {
        AsyncClosureOperation { completionClosure in
            if settings.notificationsEnabled {
                syncService.save(
                    settings: settings.accountBased,
                    runningIn: nil,
                    completionHandler: { optError in
                        if let error = optError {
                            completionClosure(.failure(error))
                        } else {
                            completionClosure(.success(()))
                        }
                    }
                )
            } else {
                syncService.disableRemote(
                    settings: settings.accountBased,
                    runningIn: nil,
                    completionHandler: { optError in
                        if let error = optError {
                            completionClosure(.failure(error))
                        } else {
                            completionClosure(.success(()))
                        }
                    }
                )
            }
        }
    }

    private func createTopicsUpdate(
        from settings: PushNotification.AllSettings,
        notificationsWereEnabledBefore: Bool,
        topicService: PushNotificationsTopicServiceProtocol
    ) -> BaseOperation<Void> {
        AsyncClosureOperation { completionClosure in
            if !notificationsWereEnabledBefore {
                topicService.save(
                    settings: settings.topics,
                    callbackQueue: nil
                ) { optError in
                    if let error = optError {
                        completionClosure(.failure(error))
                    } else {
                        completionClosure(.success(()))
                    }
                }
            } else {
                // in case notifications were not enabled we need to wait the token
                topicService.saveDiff(
                    settings: settings.topics,
                    callbackQueue: nil
                ) { optError in
                    if let error = optError {
                        completionClosure(.failure(error))
                    } else {
                        completionClosure(.success(()))
                    }
                }
            }
        }
    }

    private func updateWeb3PushToken(using token: String) {
        guard let syncService = syncService else {
            logger.warning("Push notification token received but sync is not available")
            return
        }

        guard !token.isEmpty else {
            logger.warning("Empty token push token received. No update.")
            return
        }

        syncService.update(
            token: token,
            runningIn: nil
        ) { [weak self] in
            self?.logger.debug("Push notification update completed")
        }
    }
}

extension PushNotificationsServiceFacade: PushNotificationsStatusServiceDelegate {
    func didReceivePushNotifications(token: String) {
        updateWeb3PushToken(using: token)
    }
}

extension PushNotificationsServiceFacade: PushNotificationsServiceFacadeProtocol {
    func setup() {
        guard !isActive else {
            return
        }

        isActive = true

        statusService.delegate = self
        statusService.setup()

        subscribeStatus()
    }

    func throttle() {
        guard isActive else {
            return
        }

        isActive = false

        statusService.delegate = nil
        statusService.statusObservable.removeObserver(by: self)
        statusService.throttle()

        throttleServicesIfNeeded()
    }

    // swiftlint:disable:next function_body_length
    func save(
        settings: PushNotification.AllSettings,
        completion: @escaping (Result<Void, PushNotificationsServiceFacadeError>) -> Void
    ) {
        let topicServiceWereActive = topicService != nil

        if settings.notificationsEnabled {
            statusService.enablePushNotifications()
            setupServicesForActiveStateIfNeeded()
        }

        guard let syncService = syncService else {
            dispatchInQueueWhenPossible(.main) {
                completion(.failure(.serviceUnvailable("Sync")))
            }
            return
        }

        guard let topicService = topicService else {
            dispatchInQueueWhenPossible(.main) {
                completion(.failure(.serviceUnvailable("Topic")))
            }
            return
        }

        let notificationsEnabledOperation = statusService.notificationsReadyOperation(with: setupTimeoutInSec)

        let accountBasedSaveOperation = createAccountBasedUpdate(
            from: settings,
            syncService: syncService
        )

        accountBasedSaveOperation.addDependency(notificationsEnabledOperation)

        accountBasedSaveOperation.configurationBlock = {
            do {
                try notificationsEnabledOperation.extractNoCancellableResultData()
            } catch {
                accountBasedSaveOperation.result = .failure(error)
            }
        }

        let topicsSaveOperation = createTopicsUpdate(
            from: settings,
            notificationsWereEnabledBefore: topicServiceWereActive,
            topicService: topicService
        )

        topicsSaveOperation.configurationBlock = {
            do {
                try notificationsEnabledOperation.extractNoCancellableResultData()
            } catch {
                topicsSaveOperation.result = .failure(error)
            }
        }

        topicsSaveOperation.addDependency(accountBasedSaveOperation)

        topicsSaveOperation.completionBlock = { [weak self] in
            dispatchInQueueWhenPossible(.main) {
                do {
                    try accountBasedSaveOperation.extractNoCancellableResultData()
                    try topicsSaveOperation.extractNoCancellableResultData()

                    if !settings.notificationsEnabled {
                        self?.statusService.disablePushNotifications()
                    }

                    if settings.notificationsEnabled {
                        self?.refreshPushTokenIfNeeded()
                    }

                    completion(.success(()))
                } catch {
                    completion(.failure(.settingsUpdateFailed(error)))
                }
            }
        }

        operationQueue.addOperations(
            [notificationsEnabledOperation, accountBasedSaveOperation, topicsSaveOperation],
            waitUntilFinished: false
        )
    }

    func subscribeStatus(
        _ target: AnyObject,
        closure: @escaping (PushNotificationsStatus, PushNotificationsStatus) -> Void
    ) {
        statusService.statusObservable.addObserver(
            with: target,
            sendStateOnSubscription: true,
            queue: .main,
            closure: closure
        )
    }

    func unsubscribeStatus(_ target: AnyObject) {
        statusService.statusObservable.removeObserver(by: target)
    }

    func updateAPNS(token: Data) {
        statusService.updateAPNS(token: token)
    }

    func syncWallets() {
        walletsUpdateService?.syncUp()
    }
}
