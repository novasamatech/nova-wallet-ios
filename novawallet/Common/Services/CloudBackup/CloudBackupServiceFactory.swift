import Foundation
import Keystore_iOS

final class ICloudBackupServiceFactory {
    let containerId: String
    let fileManager: FileManager
    let fileCoordinator: NSFileCoordinator
    let logger: LoggerProtocol
    let notificationCenter: NotificationCenter

    init(
        containerId: String = CloudBackup.containerId,
        fileManager: FileManager = FileManager.default,
        fileCoordinator: NSFileCoordinator = NSFileCoordinator(),
        notificationCenter: NotificationCenter = .default,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.containerId = containerId
        self.fileManager = fileManager
        self.fileCoordinator = fileCoordinator
        self.notificationCenter = notificationCenter
        self.logger = logger
    }
}

extension ICloudBackupServiceFactory: CloudBackupServiceFactoryProtocol {
    func createAvailabilityService() -> CloudBackupAvailabilityServiceProtocol {
        CloudBackupAvailabilityService(fileManager: fileManager, logger: logger)
    }

    func createOperationFactory() -> CloudBackupOperationFactoryProtocol {
        CloudBackupOperationFactory(
            fileCoordinator: fileCoordinator,
            fileManager: fileManager,
            conflictsResolver: CloudBackupConflictsResolver()
        )
    }

    func createFileManager() -> CloudBackupFileManaging {
        ICloudBackupFileManager(fileManager: fileManager)
    }

    func createCodingManager() -> CloudBackupCoding {
        CloudBackupCoder()
    }

    func createCryptoManager() -> CloudBackupCryptoManagerProtocol {
        CloudBackupScryptSalsaCryptoManager()
    }

    func createDiffCalculator() -> CloudBackupDiffCalculating {
        CloudBackupDiffCalculator(converter: CloudBackupFileModelConverter())
    }

    func createSecretsExporter(from keychain: KeystoreProtocol) -> CloudBackupSecretsExporting {
        CloudBackupSecretsExporter(
            walletConverter: CloudBackupFileModelConverter(),
            cryptoManager: createCryptoManager(),
            validator: ICloudBackupValidator(),
            keychain: keychain
        )
    }

    func createSecretsImporter(to keychain: KeystoreProtocol) -> CloudBackupSecretsImporting {
        CloudBackupSecretsImporter(
            walletConverter: CloudBackupFileModelConverter(),
            cryptoManager: createCryptoManager(),
            validator: ICloudBackupValidator(),
            keychain: keychain
        )
    }

    func createSyncStatusMonitoring() -> CloudBackupSyncMonitoring {
        let monitoringQueue = OperationQueue()
        monitoringQueue.maxConcurrentOperationCount = 1

        return ICloudBackupSyncMonitor(
            filename: CloudBackup.walletsFilename,
            operationQueue: monitoringQueue,
            notificationCenter: notificationCenter,
            logger: logger
        )
    }
}
