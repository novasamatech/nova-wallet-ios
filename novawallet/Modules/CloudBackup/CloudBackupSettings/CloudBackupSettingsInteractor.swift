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
}
