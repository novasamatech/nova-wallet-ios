import Foundation
import Keystore_iOS
import Operation_iOS

final class UpdatedWalletNotificationsCleaner {
    private let notificationsSettingsrepository: AnyDataProviderRepository<Web3Alert.LocalSettings>
    private let notificationsTopicsRepository: AnyDataProviderRepository<PushNotification.TopicSettings>
    private let notificationsFacade: PushNotificationsServiceFacadeProtocol
    private let settingsManager: SettingsManagerProtocol
    private let operationQueue: OperationQueue

    init(
        notificationsSettingsrepository: AnyDataProviderRepository<Web3Alert.LocalSettings>,
        notificationsTopicsRepository: AnyDataProviderRepository<PushNotification.TopicSettings>,
        notificationsFacade: PushNotificationsServiceFacadeProtocol,
        settingsManager: SettingsManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.notificationsFacade = notificationsFacade
        self.notificationsSettingsrepository = notificationsSettingsrepository
        self.notificationsTopicsRepository = notificationsTopicsRepository
        self.settingsManager = settingsManager
        self.operationQueue = operationQueue
    }
}

//// MARK: - WalletStorageCleaning
//
// extension UpdatedWalletNotificationsCleaner: WalletStorageCleaning {
//    func cleanStorage(using providers: WalletStorageCleaningProviders) -> CompoundOperationWrapper<Void> {
//
//    }
// }
