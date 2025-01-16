import Foundation
import Keystore_iOS
import Operation_iOS

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
    case backupAlreadyExists
}

protocol CloudBackupServiceFacadeProtocol {
    func createBackup(
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

    func checkBackupPassword(
        _ password: String,
        runCompletionIn queue: DispatchQueue,
        completionClosure: @escaping (Result<Bool, CloudBackupServiceFacadeError>) -> Void
    )

    func changeBackupPassword(
        from oldPassword: String,
        newPassword: String,
        runCompletionIn queue: DispatchQueue,
        completionClosure: @escaping (Result<Void, CloudBackupServiceFacadeError>) -> Void
    )
}
