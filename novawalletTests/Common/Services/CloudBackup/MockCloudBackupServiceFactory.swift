import Foundation
@testable import novawallet
import SoraKeystore
import SoraFoundation

final class MockCloudBackupServiceFactory {
    let availablityService: CloudBackupAvailabilityServiceProtocol
    let operationFactory: CloudBackupOperationFactoryProtocol
    let fileManager: CloudBackupFileManaging
    let storageManager: CloudBackupStorageManaging
    
    init(
        availablityService: CloudBackupAvailabilityServiceProtocol = MockCloudBackupAvailabilityService(),
        operationFactory: CloudBackupOperationFactoryProtocol = MockCloudBackupOperationFactory(),
        fileManager: CloudBackupFileManaging = MockCloudBackupFileManager(),
        storageManager: CloudBackupStorageManaging = MockCloudBackupStorageManager()
    ) {
        self.availablityService = availablityService
        self.operationFactory = operationFactory
        self.fileManager = fileManager
        self.storageManager = storageManager
    }
}

extension MockCloudBackupServiceFactory: CloudBackupServiceFactoryProtocol {
    func createAvailabilityService() -> CloudBackupAvailabilityServiceProtocol {
       availablityService
    }
    
    func createStorageManager(for baseUrl: URL) -> CloudBackupStorageManaging {
        MockCloudBackupStorageManager()
    }
    
    func createOperationFactory() -> CloudBackupOperationFactoryProtocol {
        operationFactory
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
        MockCloudBackupUploadFactory(operationFactory: operationFactory)
    }
}
