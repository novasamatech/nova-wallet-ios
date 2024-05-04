import Foundation
import SoraKeystore

protocol CloudBackupServiceFactoryProtocol {
    func createAvailabilityService() -> CloudBackupAvailabilityServiceProtocol
    func createStorageManager(for baseUrl: URL) -> CloudBackupStorageManaging
    func createOperationFactory() -> CloudBackupOperationFactoryProtocol
    func createFileManager() -> CloudBackupFileManaging
    func createCodingManager() -> CloudBackupCoding
    func createSecretsExporter(from keychain: KeystoreProtocol) -> CloudBackupSecretsExporting
    func createSecretsImporter(to keychain: KeystoreProtocol) -> CloudBackupSecretsImporting
    func createUploadFactory() -> CloudBackupUploadFactoryProtocol
}
