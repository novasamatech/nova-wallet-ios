import Keystore_iOS
import Operation_iOS
import FirebaseCore
import FirebaseFirestore
import Foundation_iOS

protocol PushNotificationsFacadeFactoryProtocol {
    func createSyncService() -> Web3AlertsSyncServiceProtocol
    func createStatusService() -> PushNotificationsStatusServiceProtocol
    func createTopicService() -> PushNotificationsTopicServiceProtocol
    func createWalletsUpdateService(
        for settingsService: Web3AlertsSyncServiceProtocol
    ) -> SyncServiceProtocol
}

final class PushNotificationsFacadeFactory: PushNotificationsFacadeFactoryProtocol {
    let chainRegistry: ChainRegistryProtocol
    let storageFacade: StorageFacadeProtocol
    let settingsManager: SettingsManagerProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        chainRegistry: ChainRegistryProtocol,
        storageFacade: StorageFacadeProtocol,
        settingsManager: SettingsManagerProtocol = SettingsManager.shared,
        operationQueue: OperationQueue,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.chainRegistry = chainRegistry
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

    func createWalletsUpdateService(
        for settingsService: Web3AlertsSyncServiceProtocol
    ) -> SyncServiceProtocol {
        let walletsRepository = AccountRepositoryFactory(storageFacade: storageFacade).createMetaAccountRepository(
            for: nil,
            sortDescriptors: []
        )

        return Web3AlertsWalletsUpdateService(
            chainRegistry: chainRegistry,
            walletsRepository: walletsRepository,
            settingsService: settingsService,
            operationQueue: operationQueue
        )
    }
}
