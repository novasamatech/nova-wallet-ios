import Foundation
import SoraKeystore

final class ICloudBackupServiceFactory {
    let containerId: String
    let fileManager: FileManager
    let fileCoordinator: NSFileCoordinator
    let logger: LoggerProtocol
    let operationQueue: OperationQueue
    let notificationCenter: NotificationCenter
    let monitoringQueue: OperationQueue

    init(
        containerId: String = CloudBackup.containerId,
        fileManager: FileManager = FileManager.default,
        fileCoordinator: NSFileCoordinator = NSFileCoordinator(),
        operationQueue: OperationQueue,
        notificationCenter: NotificationCenter = .default,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.containerId = containerId
        self.fileManager = fileManager
        self.fileCoordinator = fileCoordinator
        self.operationQueue = operationQueue
        self.notificationCenter = notificationCenter

        monitoringQueue = OperationQueue()
        monitoringQueue.maxConcurrentOperationCount = 1

        self.logger = logger
    }
}

extension ICloudBackupServiceFactory: CloudBackupServiceFactoryProtocol {
    func createAvailabilityService() -> CloudBackupAvailabilityServiceProtocol {
        CloudBackupAvailabilityService(fileManager: fileManager, logger: logger)
    }

    func createStorageManager(for baseUrl: URL) -> CloudBackupStorageManaging {
        let cloudOperationFactory = createOperationFactory()

        let uploadOperationFactory = ICloudBackupUploadFactory(
            operationFactory: cloudOperationFactory,
            monitoringOperationQueue: monitoringQueue,
            notificationCenter: notificationCenter,
            logger: logger
        )

        return ICloudBackupStorageManager(
            baseUrl: baseUrl,
            cloudOperationFactory: cloudOperationFactory,
            uploadOperationFactory: uploadOperationFactory,
            operationQueue: operationQueue,
            workingQueue: .global(),
            notificationCenter: notificationCenter,
            logger: logger
        )
    }

    func createOperationFactory() -> CloudBackupOperationFactoryProtocol {
        CloudBackupOperationFactory(
            fileCoordinator: fileCoordinator,
            fileManager: fileManager
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

    func createUploadFactory() -> CloudBackupUploadFactoryProtocol {
        ICloudBackupUploadFactory(
            operationFactory: createOperationFactory(),
            monitoringOperationQueue: monitoringQueue,
            notificationCenter: notificationCenter,
            logger: logger
        )
    }
}
