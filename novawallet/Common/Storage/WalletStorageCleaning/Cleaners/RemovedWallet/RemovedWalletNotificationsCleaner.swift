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

// MARK: - Private

private extension RemoverStorageNotificationsCleaner {
    func createCleaningWrapper(
        using providers: WalletStorageCleaningProviders
    ) -> CompoundOperationWrapper<Void> {
        let unregisterWrapper = createUnregisterOperation(using: providers)
            
        let localCleaningWrapper: CompoundOperationWrapper<Void>
        localCleaningWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            let updatedAllSettings = try unregisterWrapper.targetOperation.extractNoCancellableResultData()
            
            let removeSettingsOperation = self.notificationsSettingsrepository.saveOperation(
                { [updatedAllSettings.accountBased] },
                { [] }
            )
            
            return CompoundOperationWrapper(targetOperation: removeSettingsOperation)
        }
        
        localCleaningWrapper.addDependency(wrapper: unregisterWrapper)
        
        return localCleaningWrapper.insertingHead(operations: unregisterWrapper.allOperations)
    }
    
    func createUnregisterOperation(
        using providers: WalletStorageCleaningProviders
    ) -> CompoundOperationWrapper<PushNotification.AllSettings> {
        let settingsOperation = notificationsSettingsrepository.fetchAllOperation(with: .init())
        let topicsOperation = notificationsTopicsRepository.fetchAllOperation(with: .init())

        let unregisterOperation = AsyncClosureOperation<PushNotification.AllSettings> { [weak self] completion in
            guard let self else {
                throw BaseOperationError.parentOperationCancelled
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
                throw RemovedWalletNotificationsCleanerError.settingsNotFound
            }

            let updatedWallets = settings.wallets.filter { !metaIds.contains($0.metaId) }
            let updatedSettings = settings.with(wallets: updatedWallets)

            let updatedAllSettings = PushNotification.AllSettings(
                notificationsEnabled: settingsManager.notificationsEnabled,
                accountBased: updatedSettings.settingCurrentDate(),
                topics: topicSettings
            )

            self.notificationsFacade.save(
                settings: updatedAllSettings,
                completion: { result in
                    switch result {
                    case .success:
                        completion(.success(updatedAllSettings))
                    case let .failure(error):
                        completion(.failure(error))
                    }
                }
            )
        }
        
        unregisterOperation.addDependency(settingsOperation)
        unregisterOperation.addDependency(topicsOperation)
        
        let dependencies = [settingsOperation, topicsOperation]

        return CompoundOperationWrapper(
            targetOperation: unregisterOperation,
            dependencies: dependencies
        )
    }
}

// MARK: - WalletStorageCleaning

extension RemoverStorageNotificationsCleaner: WalletStorageCleaning {
    func cleanStorage(
        using providers: WalletStorageCleaningProviders
    ) -> CompoundOperationWrapper<Void> {
        createCleaningWrapper(using: providers)
    }
}

// MARK: - Errors

enum RemovedWalletNotificationsCleanerError: Error {
    case settingsNotFound
}
