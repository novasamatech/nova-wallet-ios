import Foundation
import SoraKeystore

extension CloudBackupSyncFacade {
    static func createFacade() -> CloudBackupSyncFacadeProtocol {
        let operationQueue = OperationManagerFacade.cloudBackupQueue
        let serviceFactory = ICloudBackupServiceFactory(operationQueue: operationQueue)
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
            operationQueue: operationQueue,
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
