import Foundation
import Keystore_iOS
import Operation_iOS

final class RemovedWalletNotificationsCleaner: WalletNotificationsCleaner {
    private let notificationsTopicsRepository: AnyDataProviderRepository<PushNotification.TopicSettings>
    private let settingsManager: SettingsManagerProtocol

    init(
        notificationsSettingsRepository: AnyDataProviderRepository<Web3Alert.LocalSettings>,
        notificationsTopicsRepository: AnyDataProviderRepository<PushNotification.TopicSettings>,
        notificationsFacade: PushNotificationsServiceFacadeProtocol,
        settingsManager: SettingsManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.notificationsTopicsRepository = notificationsTopicsRepository
        self.settingsManager = settingsManager

        super.init(
            notificationsFacade: notificationsFacade,
            notificationsSettingsRepository: notificationsSettingsRepository,
            operationQueue: operationQueue
        )
    }

    override func createUpdatedSettingsWrapper(
        using providers: WalletStorageCleaningProviders
    ) -> CompoundOperationWrapper<PushNotification.AllSettings?> {
        OperationCombiningService.compoundOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) { [weak self] in
            guard let self else {
                throw BaseOperationError.parentOperationCancelled
            }

            let metaIds = Set(
                try providers.changesProvider()
                    .filter { $0.isDeletion }
                    .map(\.identifier)
            )

            guard !metaIds.isEmpty else {
                return .createWithResult(nil)
            }

            return createUpdatedSettingsWrapper(for: metaIds)
        }
    }
}

// MARK: - Private

private extension RemovedWalletNotificationsCleaner {
    func createUpdatedSettingsWrapper(
        for metaIds: Set<MetaAccountModel.Id>
    ) -> CompoundOperationWrapper<PushNotification.AllSettings?> {
        let settingsOperation = notificationsSettingsRepository.fetchAllOperation(with: .init())
        let topicsOperation = notificationsTopicsRepository.fetchAllOperation(with: .init())

        let resultOperation = ClosureOperation<PushNotification.AllSettings?> { [weak self] in
            guard let self else {
                throw BaseOperationError.parentOperationCancelled
            }

            guard
                let settings = try settingsOperation.extractNoCancellableResultData().first,
                let topicSettings = try topicsOperation.extractNoCancellableResultData().first
            else {
                return nil
            }

            let updatedWallets = settings.wallets.filter { !metaIds.contains($0.metaId) }
            let updatedSettings = settings.with(wallets: updatedWallets)

            return PushNotification.AllSettings(
                notificationsEnabled: settingsManager.notificationsEnabled,
                accountBased: updatedSettings.settingCurrentDate(),
                topics: topicSettings
            )
        }

        resultOperation.addDependency(settingsOperation)
        resultOperation.addDependency(topicsOperation)

        let dependencies = [
            settingsOperation,
            topicsOperation
        ]

        return CompoundOperationWrapper(
            targetOperation: resultOperation,
            dependencies: dependencies
        )
    }
}

// MARK: - WalletStorageCleaning

extension RemovedWalletNotificationsCleaner: WalletStorageCleaning {
    func cleanStorage(
        using providers: WalletStorageCleaningProviders
    ) -> CompoundOperationWrapper<Void> {
        createCleaningWrapper(using: providers)
    }
}
