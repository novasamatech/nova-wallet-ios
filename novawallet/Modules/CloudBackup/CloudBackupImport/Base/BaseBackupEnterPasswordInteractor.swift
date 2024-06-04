import UIKit
import RobinHood
import SoraKeystore

class BaseBackupEnterPasswordInteractor {
    weak var presenter: ImportCloudPasswordInteractorOutputProtocol?

    let cloudBackupSyncFacade: CloudBackupSyncFacadeProtocol
    let cloudBackupServiceFacade: CloudBackupServiceFacadeProtocol

    init(
        cloudBackupSyncFacade: CloudBackupSyncFacadeProtocol,
        cloudBackupServiceFacade: CloudBackupServiceFacadeProtocol
    ) {
        self.cloudBackupSyncFacade = cloudBackupSyncFacade
        self.cloudBackupServiceFacade = cloudBackupServiceFacade
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
        cloudBackupSyncFacade.disableBackup(runCompletionIn: .main) { [weak self] result in
            switch result {
            case .success:
                self?.cloudBackupServiceFacade.deleteBackup(runCompletionIn: .main) { result in
                    switch result {
                    case .success:
                        self?.presenter?.didDeleteBackup()
                    case let .failure(error):
                        self?.presenter?.didReceive(error: .deleteFailed(error))
                    }
                }
            case let .failure(error):
                self?.presenter?.didReceive(error: .deleteFailed(error))
            }
        }
    }
}
