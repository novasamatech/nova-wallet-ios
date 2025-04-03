import Foundation
import Keystore_iOS

extension CloudBackupSyncService {
    static func createService() -> CloudBackupSyncService {
        let operationQueue = OperationManagerFacade.cloudBackupQueue
        let serviceFactory = ICloudBackupServiceFactory()
        let syncMetadataManaging = CloudBackupSyncMetadataManager(
            settings: SettingsManager.shared,
            keystore: Keychain()
        )

        let walletsRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)

        let updateCalculationFactory = CloudBackupUpdateCalculationFactory(
            syncMetadataManager: syncMetadataManaging,
            walletsRepository: walletsRepositoryFactory.createManagedMetaAccountRepository(
                for: NSPredicate.cloudSyncableWallets,
                sortDescriptors: []
            ),
            backupOperationFactory: serviceFactory.createOperationFactory(),
            decodingManager: serviceFactory.createCodingManager(),
            cryptoManager: serviceFactory.createCryptoManager(),
            diffManager: serviceFactory.createDiffCalculator()
        )

        return CloudBackupSyncService(
            updateCalculationFactory: updateCalculationFactory,
            applyUpdateFactory: CloudBackupUpdateApplicationFactory.createDefault(),
            syncMetadataManager: syncMetadataManaging,
            fileManager: serviceFactory.createFileManager(),
            operationQueue: operationQueue,
            workQueue: .global(),
            logger: Logger.shared
        )
    }
}
