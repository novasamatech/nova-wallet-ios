import UIKit

final class CloudBackupSettingsInteractor {
    weak var presenter: CloudBackupSettingsInteractorOutputProtocol?

    let cloudBackupSyncFacade: CloudBackupSyncFacadeProtocol
    let cloudBackupApplicationFactory: CloudBackupUpdateApplicationFactoryProtocol
    let operationQueue: OperationQueue

    init(
        cloudBackupSyncFacade: CloudBackupSyncFacadeProtocol,
        cloudBackupApplicationFactory: CloudBackupUpdateApplicationFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.cloudBackupSyncFacade = cloudBackupSyncFacade
        self.cloudBackupApplicationFactory = cloudBackupApplicationFactory
        self.operationQueue = operationQueue

        startService()
    }

    deinit {
        stopService()
    }

    private func startService() {
        cloudBackupSyncFacade.setup()
    }

    private func stopService() {
        cloudBackupSyncFacade.throttle()
    }

    private func subscribeBackupState() {
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

    func apply(changes _: CloudBackupSyncResult.Changes) {}
}
