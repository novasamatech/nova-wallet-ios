import Foundation
import SoraKeystore

extension CloudBackupSyncFacade {
    static func createFacade() -> CloudBackupSyncFacadeProtocol {
        let serviceFactory = ICloudBackupServiceFactory(operationQueue: OperationManagerFacade.sharedDefaultQueue)
        let syncMetadataManaging = CloudBackupSyncMetadataManager(
            settings: SettingsManager.shared,
            keystore: Keychain()
        )

        let walletsRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)

        let syncFactory = CloudBackupSyncFactory(
            serviceFactory: serviceFactory,
            syncMetadataManaging: syncMetadataManaging,
            walletsRepositoryFactory: walletsRepositoryFactory,
            notificationCenter: NotificationCenter.default,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )

        return CloudBackupSyncFacade(
            syncFactory: syncFactory,
            syncMetadataManager: syncMetadataManaging,
            fileManager: serviceFactory.createFileManager(),
            workingQueue: .global(),
            logger: Logger.shared
        )
    }
}
