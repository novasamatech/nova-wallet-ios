import UIKit
import Operation_iOS
import Keystore_iOS

class BaseBackupEnterPasswordInteractor {
    weak var presenter: ImportCloudPasswordInteractorOutputProtocol?

    let cloudBackupServiceFacade: CloudBackupServiceFacadeProtocol
    let syncMetadataManager: CloudBackupSyncMetadataManaging

    init(
        cloudBackupServiceFacade: CloudBackupServiceFacadeProtocol,
        syncMetadataManager: CloudBackupSyncMetadataManaging
    ) {
        self.cloudBackupServiceFacade = cloudBackupServiceFacade
        self.syncMetadataManager = syncMetadataManager
    }

    private func handleImport(error: CloudBackupServiceFacadeError) {
        switch error {
        case let .backupDecoding(error):
            presenter?.didReceive(error: .backupBroken(error))
        case .invalidBackupPassword:
            presenter?.didReceive(error: .invalidPassword)
        default:
            presenter?.didReceive(error: .importInternal(error))
        }
    }

    func proceedAfterPasswordValid(_: String) {
        fatalError("Must be overriden by subsclass")
    }
}

extension BaseBackupEnterPasswordInteractor: ImportCloudPasswordInteractorInputProtocol {
    func importBackup(for password: String) {
        cloudBackupServiceFacade.checkBackupPassword(
            password,
            runCompletionIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(isValid):
                if isValid {
                    self?.proceedAfterPasswordValid(password)
                } else {
                    self?.presenter?.didReceive(error: .invalidPassword)
                }
            case let .failure(error):
                self?.handleImport(error: error)
            }
        }
    }

    func deleteBackup() {
        cloudBackupServiceFacade.deleteBackup(runCompletionIn: .main) { [weak self] result in
            switch result {
            case .success:
                do {
                    try self?.syncMetadataManager.deleteBackup()
                    self?.presenter?.didDeleteBackup()
                } catch {
                    self?.presenter?.didReceive(error: .deleteFailed(error))
                }
            case let .failure(error):
                self?.presenter?.didReceive(error: .deleteFailed(error))
            }
        }
    }
}
