import Foundation
import Keystore_iOS
import Operation_iOS

class WalletNotificationsCleaner {
    let notificationsFacade: PushNotificationsServiceFacadeProtocol
    let notificationsSettingsRepository: AnyDataProviderRepository<Web3Alert.LocalSettings>
    let operationQueue: OperationQueue

    init(
        notificationsFacade: PushNotificationsServiceFacadeProtocol,
        notificationsSettingsRepository: AnyDataProviderRepository<Web3Alert.LocalSettings>,
        operationQueue: OperationQueue
    ) {
        self.notificationsFacade = notificationsFacade
        self.notificationsSettingsRepository = notificationsSettingsRepository
        self.operationQueue = operationQueue
    }

    func createUpdatedSettingsWrapper(
        using _: WalletStorageCleaningProviders
    ) -> CompoundOperationWrapper<PushNotification.AllSettings?> {
        fatalError("Must be overridden in subclass")
    }
}

// MARK: - Private

private extension WalletNotificationsCleaner {
    func createUpdateSettingsWrapper(
        using providers: WalletStorageCleaningProviders
    ) -> CompoundOperationWrapper<PushNotification.AllSettings?> {
        let updatedSettingsWrapper = createUpdatedSettingsWrapper(using: providers)

        let saveSettingsOperation = AsyncClosureOperation<PushNotification.AllSettings?> { [weak self] completion in
            guard let self else {
                throw BaseOperationError.parentOperationCancelled
            }

            let updatedSettings = try updatedSettingsWrapper.targetOperation.extractNoCancellableResultData()

            guard let updatedSettings else {
                completion(.success(nil))
                return
            }

            self.notificationsFacade.save(
                settings: updatedSettings,
                completion: { result in
                    switch result {
                    case .success:
                        completion(.success(updatedSettings))
                    case let .failure(error):
                        completion(.failure(error))
                    }
                }
            )
        }

        saveSettingsOperation.addDependency(updatedSettingsWrapper.targetOperation)

        return updatedSettingsWrapper.insertingTail(operation: saveSettingsOperation)
    }
}

// MARK: - Internal

extension WalletNotificationsCleaner {
    func createCleaningWrapper(
        using providers: WalletStorageCleaningProviders
    ) -> CompoundOperationWrapper<Void> {
        let updateWrapper = createUpdateSettingsWrapper(using: providers)

        let localCleaningWrapper: CompoundOperationWrapper<Void>
        localCleaningWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            let updatedAllSettings = try updateWrapper.targetOperation.extractNoCancellableResultData()

            guard let updatedAllSettings else { return .createWithResult(()) }

            let removeSettingsOperation = self.notificationsSettingsRepository.saveOperation(
                { [updatedAllSettings.accountBased] },
                { [] }
            )

            return CompoundOperationWrapper(targetOperation: removeSettingsOperation)
        }

        localCleaningWrapper.addDependency(wrapper: updateWrapper)

        return localCleaningWrapper.insertingHead(operations: updateWrapper.allOperations)
    }
}
