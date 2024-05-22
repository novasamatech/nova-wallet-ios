import Foundation

protocol CloudBackupSyncFactoryProtocol {
    func createSyncService(for remoteFileUrl: URL) -> CloudBackupSyncServiceProtocol
    func createRemoteUpdatesMonitor(for filename: String) -> CloudBackupUpdateMonitoring
}

final class CloudBackupSyncFactory {
    let syncMetadataManaging: CloudBackupSyncMetadataManaging
    let walletsRepositoryFactory: AccountRepositoryFactoryProtocol
    let serviceFactory: CloudBackupServiceFactoryProtocol
    let operationQueue: OperationQueue
    let notificationCenter: NotificationCenter
    let logger: LoggerProtocol

    init(
        serviceFactory: CloudBackupServiceFactoryProtocol,
        syncMetadataManaging: CloudBackupSyncMetadataManaging,
        walletsRepositoryFactory: AccountRepositoryFactoryProtocol,
        notificationCenter: NotificationCenter,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.serviceFactory = serviceFactory
        self.syncMetadataManaging = syncMetadataManaging
        self.walletsRepositoryFactory = walletsRepositoryFactory
        self.operationQueue = operationQueue
        self.notificationCenter = notificationCenter
        self.logger = logger
    }
}

extension CloudBackupSyncFactory: CloudBackupSyncFactoryProtocol {
    func createSyncService(for remoteFileUrl: URL) -> CloudBackupSyncServiceProtocol {
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
            remoteFileUrl: remoteFileUrl,
            updateCalculationFactory: updateCalculationFactory,
            operationQueue: operationQueue
        )
    }

    func createRemoteUpdatesMonitor(for filename: String) -> CloudBackupUpdateMonitoring {
        let syncQueue = OperationQueue()
        syncQueue.maxConcurrentOperationCount = 1

        return ICloudBackupUpdateMonitor(
            filename: filename,
            operationQueue: syncQueue,
            notificationCenter: notificationCenter,
            logger: logger
        )
    }
}
