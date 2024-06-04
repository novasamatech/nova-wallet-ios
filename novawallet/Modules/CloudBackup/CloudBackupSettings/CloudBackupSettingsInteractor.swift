import UIKit

final class CloudBackupSettingsInteractor {
    weak var presenter: CloudBackupSettingsInteractorOutputProtocol?

    let cloudBackupSyncMediator: CloudBackupSyncMediating
    let cloudBackupServiceFacade: CloudBackupServiceFacadeProtocol

    var cloudBackupSyncFacade: CloudBackupSyncFacadeProtocol {
        cloudBackupSyncMediator.syncFacade
    }

    init(
        cloudBackupSyncMediator: CloudBackupSyncMediating,
        cloudBackupServiceFacade: CloudBackupServiceFacadeProtocol
    ) {
        self.cloudBackupSyncMediator = cloudBackupSyncMediator
        self.cloudBackupServiceFacade = cloudBackupServiceFacade
    }

    private func subscribeBackupState() {
        cloudBackupSyncFacade.unsubscribeState(self)

        cloudBackupSyncFacade.subscribeState(
            self,
            notifyingIn: .main
        ) { [weak self] state in
            self?.presenter?.didReceive(state: state)
        }
    }
}

extension CloudBackupSettingsInteractor: CloudBackupSettingsInteractorInputProtocol {
    func setup() {
        subscribeBackupState()
    }

    func retryStateFetch() {
        subscribeBackupState()
    }

    func enableBackup() {
        cloudBackupSyncFacade.enableBackup(
            for: nil,
            runCompletionIn: .main
        ) { [weak self] result in
            guard case let .failure(error) = result else {
                return
            }

            self?.presenter?.didReceive(error: .enableBackup(error))
        }
    }

    func disableBackup() {
        cloudBackupSyncFacade.disableBackup(runCompletionIn: .main) { [weak self] result in
            guard case let .failure(error) = result else {
                return
            }

            self?.presenter?.didReceive(error: .disableBackup(error))
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
                        self?.presenter?.didReceive(error: .deleteBackup(error))
                    }
                }
            case let .failure(error):
                self?.presenter?.didReceive(error: .deleteBackup(error))
            }
        }
    }

    func checkBackupChangesConfirmationNeeded() {
        let state = cloudBackupSyncMediator.syncFacade.getState()

        guard let changes = state.changes else {
            return
        }

        presenter?.didReceiveConfirmation(changes: changes)
    }

    func approveBackupChanges() {
        cloudBackupSyncMediator.approveCurrentChanges()
    }
}
