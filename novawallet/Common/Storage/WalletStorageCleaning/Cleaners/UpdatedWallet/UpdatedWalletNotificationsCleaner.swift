import Foundation
import Keystore_iOS
import Operation_iOS

final class UpdatedWalletNotificationsCleaner: WalletNotificationsCleaner {
    private let pushNotificationSettingsFactory: PushNotificationSettingsFactoryProtocol
    private let chainRepository: AnyDataProviderRepository<ChainModel>
    private let notificationsTopicsRepository: AnyDataProviderRepository<PushNotification.TopicSettings>
    private let settingsManager: SettingsManagerProtocol

    init(
        pushNotificationSettingsFactory: PushNotificationSettingsFactoryProtocol,
        chainRepository: AnyDataProviderRepository<ChainModel>,
        notificationsSettingsRepository: AnyDataProviderRepository<Web3Alert.LocalSettings>,
        notificationsTopicsRepository: AnyDataProviderRepository<PushNotification.TopicSettings>,
        notificationsFacade: PushNotificationsServiceFacadeProtocol,
        settingsManager: SettingsManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.pushNotificationSettingsFactory = pushNotificationSettingsFactory
        self.chainRepository = chainRepository
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
        let chainsFetchOperation = chainRepository.fetchAllOperation(with: .init())
        let settingsOperation = notificationsSettingsRepository.fetchAllOperation(with: .init())
        let topicsOperation = notificationsTopicsRepository.fetchAllOperation(with: .init())

        let resultOperation = ClosureOperation<PushNotification.AllSettings?> { [weak self] in
            guard let self else {
                throw BaseOperationError.parentOperationCancelled
            }

            let updatedMetaAccounts = try providers.changesProvider().compactMap(\.item)
            let metaAccountsBeforeChanges = try providers.walletsBeforeChangesProvider()

            let metaAccountsToRegister = updatedMetaAccounts.filter { updatedMetaAccount in
                guard let metaAccount = metaAccountsBeforeChanges[updatedMetaAccount.info.metaId]?.info else {
                    return false
                }

                return metaAccount.chainAccounts != updatedMetaAccount.info.chainAccounts
            }

            guard !metaAccountsToRegister.isEmpty else {
                return nil
            }

            let chains = try chainsFetchOperation.extractNoCancellableResultData().reduceToDict()

            guard
                let settings = try settingsOperation.extractNoCancellableResultData().first,
                let topicSettings = try topicsOperation.extractNoCancellableResultData().first
            else {
                return nil
            }

            let settingsWallets = metaAccountsToRegister
                .filter { metaAccount in
                    settings.wallets.contains { $0.metaId == metaAccount.info.metaId }
                }
                .map { self.pushNotificationSettingsFactory.createWallet(from: $0.info, chains: chains) }

            guard !settingsWallets.isEmpty else {
                return nil
            }

            let updatedSettings = settings.with(wallets: settingsWallets)

            return PushNotification.AllSettings(
                notificationsEnabled: settingsManager.notificationsEnabled,
                accountBased: updatedSettings.settingCurrentDate(),
                topics: topicSettings
            )
        }

        resultOperation.addDependency(chainsFetchOperation)
        resultOperation.addDependency(settingsOperation)
        resultOperation.addDependency(topicsOperation)

        let dependencies = [
            chainsFetchOperation,
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

extension UpdatedWalletNotificationsCleaner: WalletStorageCleaning {
    func cleanStorage(using providers: WalletStorageCleaningProviders) -> CompoundOperationWrapper<Void> {
        createCleaningWrapper(using: providers)
    }
}
