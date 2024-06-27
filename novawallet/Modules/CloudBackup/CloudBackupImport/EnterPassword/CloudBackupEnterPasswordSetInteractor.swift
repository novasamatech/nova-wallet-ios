import Foundation

final class CloudBackupEnterPasswordSetInteractor: BaseBackupEnterPasswordInteractor {
    override func proceedAfterPasswordValid(_ password: String) {
        do {
            try syncMetadataManager.savePassword(password)
            presenter?.didImportBackup(with: password)
        } catch {
            presenter?.didReceive(error: .importInternal(error))
        }
    }
}
