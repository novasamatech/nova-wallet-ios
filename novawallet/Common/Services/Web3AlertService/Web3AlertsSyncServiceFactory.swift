import SoraKeystore
import RobinHood
import FirebaseCore
import FirebaseFirestore

protocol Web3AlertsServicesFactoryProtocol {
    func createSyncService() -> Web3AlertsSyncServiceProtocol
    func createPushNotificationsService() -> PushNotificationsServiceProtocol
}

final class Web3AlertsServicesFactory: Web3AlertsServicesFactoryProtocol {
    let storageFacade: StorageFacadeProtocol
    let settingsManager: SettingsManagerProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol
    private var syncService: Web3AlertsSyncServiceProtocol?

    static var shared: Web3AlertsServicesFactory = .init(
        storageFacade: UserDataStorageFacade.shared,
        operationQueue: OperationManagerFacade.sharedDefaultQueue
    )

    init(
        storageFacade: StorageFacadeProtocol,
        settingsManager: SettingsManagerProtocol = SettingsManager.shared,
        operationQueue: OperationQueue,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.storageFacade = storageFacade
        self.settingsManager = settingsManager
        self.operationQueue = operationQueue
        self.logger = logger
    }

    func createSyncService() -> Web3AlertsSyncServiceProtocol {
        let repository: CoreDataRepository<LocalPushSettings, CDUserSingleValue> =
            storageFacade.createRepository(mapper: AnyCoreDataMapper(Web3AlertSettingsMapper()))

        let service = Web3AlertsSyncService(
            repository: AnyDataProviderRepository(repository),
            settingsManager: settingsManager,
            operationQueue: operationQueue
        )

        syncService = service

        return service
    }

    func createPushNotificationsService() -> PushNotificationsServiceProtocol {
        if syncService == nil {
            syncService = createSyncService()
        }

        return PushNotificationsService(
            service: syncService,
            settingsManager: settingsManager,
            logger: logger
        )
    }
}
