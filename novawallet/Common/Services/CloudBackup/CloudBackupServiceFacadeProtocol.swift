import Foundation
import SoraKeystore
import RobinHood

enum CloudBackupServiceFacadeError: Error {
    case cloudNotAvailable
    case backupReading(Error)
    case facadeInternal(Error)
    case backupExport(Error)
    case backupUpload(Error)
    case backupDelete(Error)
    case backupDecoding(Error)
    case invalidBackupPassword
    case noBackup
}

protocol CloudBackupServiceFacadeProtocol {
    func enableBackup(
        wallets: Set<MetaAccountModel>,
        keystore: KeystoreProtocol,
        password: String,
        runCompletionIn queue: DispatchQueue,
        completionClosure: @escaping (Result<Void, CloudBackupServiceFacadeError>) -> Void
    )

    func importBackup(
        to repository: AnyDataProviderRepository<ManagedMetaAccountModel>,
        keystore: KeystoreProtocol,
        password: String,
        runCompletionIn queue: DispatchQueue,
        completionClosure: @escaping (Result<Set<MetaAccountModel>, CloudBackupServiceFacadeError>) -> Void
    )

    func deleteBackup(
        runCompletionIn queue: DispatchQueue,
        completionClosure: @escaping (Result<Void, CloudBackupServiceFacadeError>) -> Void
    )

    func checkBackupExists(
        runCompletionIn queue: DispatchQueue,
        completionClosure: @escaping (Result<Bool, CloudBackupServiceFacadeError>) -> Void
    )
}
