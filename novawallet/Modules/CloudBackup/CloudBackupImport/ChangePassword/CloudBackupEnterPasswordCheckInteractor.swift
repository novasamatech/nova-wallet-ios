import Foundation

final class CloudBackupEnterPasswordCheckInteractor: BaseBackupEnterPasswordInteractor {
    override func proceedAfterPasswordValid(_ password: String) {
        presenter?.didImportBackup(with: password)
    }
}
