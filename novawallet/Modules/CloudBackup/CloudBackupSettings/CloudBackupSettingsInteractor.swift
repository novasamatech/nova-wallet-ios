import UIKit

final class CloudBackupSettingsInteractor {
    weak var presenter: CloudBackupSettingsInteractorOutputProtocol?

    let cloudBackupSyncMediator: CloudBackupSyncMediating
    let cloudBackupServiceFacade: CloudBackupServiceFacadeProtocol
    let syncMetadataManager: CloudBackupSyncMetadataManaging

    var cloudBackupSyncService: CloudBackupSyncServiceProtocol {
        cloudBackupSyncMediator.syncService
    }

    init(
        cloudBackupSyncMediator: CloudBackupSyncMediating,
        cloudBackupServiceFacade: CloudBackupServiceFacadeProtocol,
        syncMetadataManager: CloudBackupSyncMetadataManaging
    ) {
        self.cloudBackupSyncMediator = cloudBackupSyncMediator
        self.cloudBackupServiceFacade = cloudBackupServiceFacade
        self.syncMetadataManager = syncMetadataManager
    }

    private func subscribeBackupState() {
        cloudBackupSyncService.unsubscribeState(self)

        cloudBackupSyncService.subscribeState(
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

    func syncUp() {
        cloudBackupSyncService.syncUp()
    }

    func becomeActive() {
        cloudBackupSyncMediator.disableDelegateNotifications()

        cloudBackupSyncService.syncUp()
    }

    func becomeInactive() {
        cloudBackupSyncMediator.enableDelegateNotifications()
    }

    func enableBackup() {
        syncMetadataManager.isBackupEnabled = true
        cloudBackupSyncService.syncUp()
    }

    func disableBackup() {
        syncMetadataManager.isBackupEnabled = false
        cloudBackupSyncService.syncUp()
    }

    func deleteBackup() {
        cloudBackupServiceFacade.deleteBackup(runCompletionIn: .main) { [weak self] result in
            switch result {
            case .success:
                self?.syncMetadataManager.isBackupEnabled = false
                self?.cloudBackupSyncService.syncUp()
                self?.presenter?.didDeleteBackup()
            case let .failure(error):
                self?.presenter?.didReceive(error: .deleteBackup(error))
            }
        }
    }

    func approveBackupChanges() {
        cloudBackupSyncMediator.approveCurrentChanges()
    }
}
