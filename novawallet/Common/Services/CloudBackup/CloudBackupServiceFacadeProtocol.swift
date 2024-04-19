import Foundation
import SoraKeystore

enum CloudBackupServiceFacadeError: Error {}

protocol CloudBackupServiceFacadeProtocol {
    func enableBackup(
        wallets: Set<MetaAccountModel>,
        keystore: KeystoreProtocol,
        password: String,
        runCompletionIn queue: DispatchQueue,
        completionClosure: (Result<Void, CloudBackupServiceFacadeError>) -> Void
    )

    func fetchRemoteBackup(
        runCompletionIn queue: DispatchQueue,
        completionClosure: (Result<CloudBackup.EncryptedFileModel?, CloudBackupServiceFacadeError>) -> Void
    )

    func subscribeState(for obsever: AnyObject)
    func unsubscribeState(for obsever: AnyObject)

    func applyBackup(
        runCompletionIn queue: DispatchQueue,
        completionClosure: (Result<Void, CloudBackupServiceFacadeError>) -> Void
    )
}
