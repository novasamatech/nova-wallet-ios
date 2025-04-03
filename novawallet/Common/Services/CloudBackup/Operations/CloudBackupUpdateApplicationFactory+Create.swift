import Foundation
import Keystore_iOS

extension CloudBackupUpdateApplicationFactory {
    static func createDefault() -> CloudBackupUpdateApplicationFactory {
        let operationQueue = OperationManagerFacade.cloudBackupQueue
        let serviceFactory = ICloudBackupServiceFactory()
        let syncMetadataManaging = CloudBackupSyncMetadataManager(
            settings: SettingsManager.shared,
            keystore: Keychain()
        )

        let walletsRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)

        let walletsRepository = walletsRepositoryFactory.createManagedMetaAccountRepository(
            for: nil,
            sortDescriptors: []
        )

        let walletStorageCleaner = WalletStorageCleanerFactory.createWalletStorageCleaner(
            using: operationQueue
        )

        let walletsUpdater = WalletUpdateMediator(
            selectedWalletSettings: SelectedWalletSettings.shared,
            repository: walletsRepository,
            walletsCleaner: walletStorageCleaner,
            operationQueue: operationQueue
        )

        return CloudBackupUpdateApplicationFactory(
            serviceFactory: serviceFactory,
            walletRepositoryFactory: walletsRepositoryFactory,
            walletsUpdater: walletsUpdater,
            keystore: Keychain(),
            syncMetadataManager: syncMetadataManaging,
            operationQueue: operationQueue
        )
    }
}
