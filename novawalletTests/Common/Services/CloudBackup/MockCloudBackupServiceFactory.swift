import Foundation
@testable import novawallet
import Keystore_iOS
import Foundation_iOS

final class MockCloudBackupServiceFactory {
    let availablityService: CloudBackupAvailabilityServiceProtocol
    let operationFactory: CloudBackupOperationFactoryProtocol
    let fileManager: CloudBackupFileManaging

    init(
        availablityService: CloudBackupAvailabilityServiceProtocol = MockCloudBackupAvailabilityService(),
        operationFactory: CloudBackupOperationFactoryProtocol = MockCloudBackupOperationFactory(),
        fileManager: CloudBackupFileManaging = MockCloudBackupFileManager()
    ) {
        self.availablityService = availablityService
        self.operationFactory = operationFactory
        self.fileManager = fileManager
    }
}

extension MockCloudBackupServiceFactory: CloudBackupServiceFactoryProtocol {
    func createAvailabilityService() -> CloudBackupAvailabilityServiceProtocol {
        availablityService
    }

    func createOperationFactory() -> CloudBackupOperationFactoryProtocol {
        operationFactory
    }

    func createSyncStatusMonitoring() -> CloudBackupSyncMonitoring {
        MockCloudBackupSyncMonitor()
    }

    func createFileManager() -> CloudBackupFileManaging {
        fileManager
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
}
