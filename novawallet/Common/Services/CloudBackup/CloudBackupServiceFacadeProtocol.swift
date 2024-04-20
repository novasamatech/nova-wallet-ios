import Foundation
import SoraKeystore

enum CloudBackupServiceFacadeError: Error {
    case cloudNotAvailable
    case backupReading(Error)
    case facadeInternal(Error)
    case backupExport(Error)
    case backupUpload(Error)
}

protocol CloudBackupServiceFacadeProtocol {
    func enableBackup(
        wallets: Set<MetaAccountModel>,
        keystore: KeystoreProtocol,
        password: String,
        runCompletionIn queue: DispatchQueue,
        completionClosure: @escaping (Result<Void, CloudBackupServiceFacadeError>) -> Void
    )

    func checkBackupExists(
        runCompletionIn queue: DispatchQueue,
        completionClosure: @escaping (Result<Bool, CloudBackupServiceFacadeError>) -> Void
    )
}
