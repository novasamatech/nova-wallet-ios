import Foundation
import Keystore_iOS
import Operation_iOS

final class RemoverStorageNotificationsCleaner {
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

// MARK: - WalletStorageCleaning

extension RemoverStorageNotificationsCleaner: WalletStorageCleaning {
    func cleanStorage(
        using providers: WalletStorageCleaningProviders
    ) -> CompoundOperationWrapper<Void> {
        let settingsOperation = notificationsSettingsrepository.fetchAllOperation(with: .init())
        let topicsOperation = notificationsTopicsRepository.fetchAllOperation(with: .init())

        let cleaningOperation = AsyncClosureOperation<Void> { [weak self] completion in
            guard let self else {
                completion(.success(()))
                return
            }

            let metaIds = Set(
                try providers.changesProvider()
                    .filter { $0.isDeletion }
                    .map(\.identifier)
            )

            guard
                let settings = try settingsOperation.extractNoCancellableResultData().first,
                let topicSettings = try topicsOperation.extractNoCancellableResultData().first
            else {
                completion(.success(()))
                return
            }

            let updatedWallets = settings.wallets.filter { !metaIds.contains($0.metaId) }
            let updatedSettings = settings.with(wallets: updatedWallets)

            let allSettings = PushNotification.AllSettings(
                notificationsEnabled: settingsManager.notificationsEnabled,
                accountBased: updatedSettings.settingCurrentDate(),
                topics: topicSettings
            )

            self.notificationsFacade.save(
                settings: allSettings,
                completion: { completion($0.mapError { $0 as Error }) }
            )
        }

        cleaningOperation.addDependency(settingsOperation)
        cleaningOperation.addDependency(topicsOperation)

        let dependencies = [settingsOperation, topicsOperation]

        return CompoundOperationWrapper(
            targetOperation: cleaningOperation,
            dependencies: dependencies
        )
    }
}
