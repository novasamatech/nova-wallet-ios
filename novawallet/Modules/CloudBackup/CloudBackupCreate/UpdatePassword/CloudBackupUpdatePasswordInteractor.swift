import Foundation

final class CloudBackupUpdatePasswordInteractor {
    weak var presenter: CloudBackupCreateInteractorOutputProtocol?

    let oldPassword: String
    let serviceFacade: CloudBackupServiceFacadeProtocol
    let syncMetadataManager: CloudBackupSyncMetadataManaging

    init(
        oldPassword: String,
        serviceFacade: CloudBackupServiceFacadeProtocol,
        syncMetadataManager: CloudBackupSyncMetadataManaging
    ) {
        self.oldPassword = oldPassword
        self.serviceFacade = serviceFacade
        self.syncMetadataManager = syncMetadataManager
    }
}

extension CloudBackupUpdatePasswordInteractor: CloudBackupCreateInteractorInputProtocol {
    func createWallet(for password: String) {
        serviceFacade.changeBackupPassword(
            from: oldPassword,
            newPassword: password,
            runCompletionIn: .main
        ) { [weak self] result in
            switch result {
            case .success:
                try? self?.syncMetadataManager.savePassword(password)
                self?.presenter?.didCreateWallet()
            case let .failure(error):
                self?.presenter?.didReceive(error: .backup(error))
            }
        }
    }
}
