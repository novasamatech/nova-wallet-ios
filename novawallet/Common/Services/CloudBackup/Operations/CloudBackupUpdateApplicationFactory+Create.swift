import Foundation
import SoraKeystore

extension CloudBackupUpdateApplicationFactory {
    static func createDefault() -> CloudBackupUpdateApplicationFactory {
        let operationQueue = OperationManagerFacade.cloudBackupQueue
        let serviceFactory = ICloudBackupServiceFactory(operationQueue: operationQueue)
        let syncMetadataManaging = CloudBackupSyncMetadataManager(
            settings: SettingsManager.shared,
            keystore: Keychain()
        )

        let walletsRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)

        let walletsRepository = walletsRepositoryFactory.createManagedMetaAccountRepository(
            for: nil,
            sortDescriptors: []
        )

        let walletsUpdater = WalletUpdateMediator(
            selectedWalletSettings: SelectedWalletSettings.shared,
            repository: walletsRepository,
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
