import Foundation
import Keystore_iOS
import Operation_iOS

enum WalletStorageCleanerFactory {
    static func createWalletStorageCleaner(using operationQueue: OperationQueue) -> WalletStorageCleaning {
        let removedNotificationsSettingsCleaner = createRemovedNotificationsSettingsCleaner(
            operationQueue: operationQueue
        )
        let removedBrowserStateCleaner = createRemovedWalletBrowserStateCleaner(
            using: operationQueue
        )
        let removedDAppSettingsCleaner = createRemovedWalletDAppSettingsCleaner()
        let updatedBrowserStateCleaner = createUpdatedWalletBrowserStateCleaner(
            using: operationQueue
        )
        let updateNotificationsSettingsCleaner = createUpdatedNotificationsSettingsCleaner(
            operationQueue: operationQueue
        )

        // Add every cleaner to the array
        // in the same order it should get called
        let cleaners = [
            removedNotificationsSettingsCleaner,
            removedBrowserStateCleaner,
            removedDAppSettingsCleaner,
            updateNotificationsSettingsCleaner,
            updatedBrowserStateCleaner
        ]

        let mainCleaner = WalletStorageCleaner(cleanersCascade: cleaners)

        return mainCleaner
    }

    // Remove

    private static func createRemovedWalletBrowserStateCleaner(
        using operationQueue: OperationQueue
    ) -> WalletStorageCleaning {
        let browserTabManager = DAppBrowserTabManager.shared
        let webViewPoolEraser = WebViewPool.shared

        let browserStateCleaner = RemovedWalletBrowserStateCleaner(
            browserTabManager: browserTabManager,
            webViewPoolEraser: webViewPoolEraser,
            operationQueue: operationQueue
        )

        return browserStateCleaner
    }

    private static func createRemovedWalletDAppSettingsCleaner() -> WalletStorageCleaning {
        let mapper = DAppSettingsMapper()
        let storageFacade = UserDataStorageFacade.shared

        let repository = storageFacade.createRepository(
            filter: nil,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )
        let authorizedDAppRepository = AnyDataProviderRepository(repository)

        let dappSettingsCleaner = RemovedWalletDAppSettingsCleaner(
            authorizedDAppRepository: authorizedDAppRepository
        )

        return dappSettingsCleaner
    }

    private static func createRemovedNotificationsSettingsCleaner(
        operationQueue: OperationQueue
    ) -> WalletStorageCleaning {
        let storageFacade = UserDataStorageFacade.shared

        let notificationsSettingsRepository = storageFacade.createRepository(
            filter: .pushSettings,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(Web3AlertSettingsMapper())
        )
        let topicsSettingsRepository = storageFacade.createRepository(
            filter: .topicSettings,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(Web3TopicSettingsMapper())
        )

        return RemovedWalletNotificationsCleaner(
            notificationsSettingsRepository: AnyDataProviderRepository(notificationsSettingsRepository),
            notificationsTopicsRepository: AnyDataProviderRepository(topicsSettingsRepository),
            notificationsFacade: PushNotificationsServiceFacade.shared,
            settingsManager: SettingsManager.shared,
            operationQueue: operationQueue
        )
    }

    // Update

    private static func createUpdatedWalletBrowserStateCleaner(
        using operationQueue: OperationQueue
    ) -> WalletStorageCleaning {
        let browserTabManager = DAppBrowserTabManager.shared
        let webViewPoolEraser = WebViewPool.shared

        let browserStateCleaner = UpdatedWalletBrowserStateCleaner(
            browserTabManager: browserTabManager,
            webViewPoolEraser: webViewPoolEraser,
            operationQueue: operationQueue
        )

        return browserStateCleaner
    }

    private static func createUpdatedNotificationsSettingsCleaner(
        operationQueue: OperationQueue
    ) -> WalletStorageCleaning {
        let storageFacade = UserDataStorageFacade.shared

        let notificationsSettingsRepository = storageFacade.createRepository(
            filter: .pushSettings,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(Web3AlertSettingsMapper())
        )
        let topicsSettingsRepository = storageFacade.createRepository(
            filter: .topicSettings,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(Web3TopicSettingsMapper())
        )
        let chainRepository = SubstrateDataStorageFacade.shared.createRepository(
            mapper: AnyCoreDataMapper(ChainModelMapper())
        )

        return UpdatedWalletNotificationsCleaner(
            pushNotificationSettingsFactory: PushNotificationSettingsFactory(),
            chainRepository: AnyDataProviderRepository(chainRepository),
            notificationsSettingsRepository: AnyDataProviderRepository(notificationsSettingsRepository),
            notificationsTopicsRepository: AnyDataProviderRepository(topicsSettingsRepository),
            notificationsFacade: PushNotificationsServiceFacade.shared,
            settingsManager: SettingsManager.shared,
            operationQueue: operationQueue
        )
    }
}
