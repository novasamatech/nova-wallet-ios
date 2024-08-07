import UIKit

final class OnboardingImportOptionsInteractor {
    weak var presenter: OnboardingImportOptionsInteractorOutputProtocol?

    let cloudBackupServiceFacade: CloudBackupServiceFacadeProtocol

    init(
        cloudBackupServiceFacade: CloudBackupServiceFacadeProtocol
    ) {
        self.cloudBackupServiceFacade = cloudBackupServiceFacade
    }

    private func handle(error: CloudBackupServiceFacadeError) {
        switch error {
        case .cloudNotAvailable:
            presenter?.didReceive(error: .cloudNotAvailable)
        default:
            presenter?.didReceive(error: .serviceInternal(error))
        }
    }
}

extension OnboardingImportOptionsInteractor: OnboardingImportOptionsInteractorInputProtocol {
    func checkExistingBackup() {
        cloudBackupServiceFacade.checkBackupExists(runCompletionIn: .main) { [weak self] result in
            switch result {
            case let .success(backupExists):
                self?.presenter?.didReceive(backupExists: backupExists)
            case let .failure(error):
                self?.handle(error: error)
            }
        }
    }
}
