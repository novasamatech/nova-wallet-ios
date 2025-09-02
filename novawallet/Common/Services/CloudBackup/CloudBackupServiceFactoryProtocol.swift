import Foundation
import Keystore_iOS

protocol CloudBackupServiceFactoryProtocol {
    func createAvailabilityService() -> CloudBackupAvailabilityServiceProtocol
    func createOperationFactory() -> CloudBackupOperationFactoryProtocol
    func createFileManager() -> CloudBackupFileManaging
    func createCodingManager() -> CloudBackupCoding
    func createCryptoManager() -> CloudBackupCryptoManagerProtocol
    func createDiffCalculator() -> CloudBackupDiffCalculating
    func createSecretsExporter(from keychain: KeystoreProtocol) -> CloudBackupSecretsExporting
    func createSecretsImporter(to keychain: KeystoreProtocol) -> CloudBackupSecretsImporting
    func createSyncStatusMonitoring() -> CloudBackupSyncMonitoring
}
