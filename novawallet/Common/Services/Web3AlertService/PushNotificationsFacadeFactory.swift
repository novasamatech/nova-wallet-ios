import SoraKeystore
import RobinHood
import FirebaseCore
import FirebaseFirestore
import SoraFoundation

protocol PushNotificationsFacadeFactoryProtocol {
    func createSyncService() -> Web3AlertsSyncServiceProtocol
    func createStatusService() -> PushNotificationsStatusServiceProtocol
    func createTopicService() -> PushNotificationsTopicServiceProtocol
}

final class PushNotificationsFacadeFactory: PushNotificationsFacadeFactoryProtocol {
    let storageFacade: StorageFacadeProtocol
    let settingsManager: SettingsManagerProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

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
        let repository: CoreDataRepository<Web3Alert.LocalSettings, CDUserSingleValue> =
            storageFacade.createRepository(
                filter: .pushSettings,
                sortDescriptors: [],
                mapper: AnyCoreDataMapper(Web3AlertSettingsMapper())
            )

        let service = Web3AlertsSyncService(
            repository: AnyDataProviderRepository(repository),
            operationQueue: operationQueue
        )

        return service
    }

    func createStatusService() -> PushNotificationsStatusServiceProtocol {
        PushNotificationsStatusService(
            settingsManager: settingsManager,
            applicationHandler: ApplicationHandler(),
            logger: logger
        )
    }

    func createTopicService() -> PushNotificationsTopicServiceProtocol {
        let repository: CoreDataRepository<PushNotification.TopicSettings, CDUserSingleValue> =
            storageFacade.createRepository(
                filter: .topicSettings,
                sortDescriptors: [],
                mapper: AnyCoreDataMapper(Web3TopicSettingsMapper())
            )

        return PushNotificationsTopicService(
            repository: AnyDataProviderRepository(repository),
            operationQueue: operationQueue,
            logger: logger
        )
    }
}
