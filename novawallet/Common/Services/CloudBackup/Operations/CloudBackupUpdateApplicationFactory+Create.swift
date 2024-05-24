import Foundation
import SoraKeystore

extension CloudBackupUpdateApplicationFactory {
    static func createDefault() -> CloudBackupUpdateApplicationFactory {
        let serviceFactory = ICloudBackupServiceFactory(operationQueue: OperationManagerFacade.sharedDefaultQueue)
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
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        return CloudBackupUpdateApplicationFactory(
            serviceFactory: serviceFactory,
            walletRepositoryFactory: walletsRepositoryFactory,
            walletsUpdater: walletsUpdater,
            keystore: Keychain(),
            syncMetadataManager: syncMetadataManaging,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
