import UIKit
import Operation_iOS

final class CloudBackupSettingsInteractor {
    weak var presenter: CloudBackupSettingsInteractorOutputProtocol?

    let cloudBackupSyncMediator: CloudBackupSyncMediating
    let cloudBackupServiceFacade: CloudBackupServiceFacadeProtocol
    let syncMetadataManager: CloudBackupSyncMetadataManaging
    let secretsWalletRepository: AnyDataProviderRepository<MetaAccountModel>
    let operationQueue: OperationQueue

    private let secretsWalletsCountCancellable = CancellableCallStore()

    var cloudBackupSyncService: CloudBackupSyncServiceProtocol {
        cloudBackupSyncMediator.syncService
    }

    init(
        cloudBackupSyncMediator: CloudBackupSyncMediating,
        cloudBackupServiceFacade: CloudBackupServiceFacadeProtocol,
        syncMetadataManager: CloudBackupSyncMetadataManaging,
        secretsWalletRepository: AnyDataProviderRepository<MetaAccountModel>,
        operationQueue: OperationQueue
    ) {
        self.cloudBackupSyncMediator = cloudBackupSyncMediator
        self.cloudBackupServiceFacade = cloudBackupServiceFacade
        self.syncMetadataManager = syncMetadataManager
        self.secretsWalletRepository = secretsWalletRepository
        self.operationQueue = operationQueue
    }

    deinit {
        secretsWalletsCountCancellable.cancel()
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

    private func subscribeSyncMonitorStatus() {
        cloudBackupSyncMediator.unsubscribeSyncMonitorStatus(for: self)

        cloudBackupSyncMediator.subscribeSyncMonitorStatus(for: self) { [weak self] _, newStatus in
            self?.presenter?.didReceive(syncMonitorStatus: newStatus)
        }
    }
}

extension CloudBackupSettingsInteractor: CloudBackupSettingsInteractorInputProtocol {
    func setup() {
        subscribeBackupState()
        subscribeSyncMonitorStatus()
    }

    func syncUp() {
        cloudBackupSyncService.syncUp()
    }

    func becomeActive() {
        cloudBackupSyncMediator.disablePresenterNotifications()

        cloudBackupSyncService.syncUp()
    }

    func becomeInactive() {
        cloudBackupSyncMediator.enablePresenterNotifications()
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
                do {
                    try self?.syncMetadataManager.deleteBackup()
                    self?.cloudBackupSyncService.syncUp()
                    self?.presenter?.didDeleteBackup()
                } catch {
                    self?.presenter?.didReceive(error: .deleteBackup(error))
                }
            case let .failure(error):
                self?.presenter?.didReceive(error: .deleteBackup(error))
            }
        }
    }

    func approveBackupChanges() {
        cloudBackupSyncMediator.approveCurrentChanges()
    }

    func fetchNumberOfWalletsWithSecrets() {
        guard !secretsWalletsCountCancellable.hasCall else {
            return
        }

        let fetchCountOperation = secretsWalletRepository.fetchCountOperation()

        execute(
            operation: fetchCountOperation,
            inOperationQueue: operationQueue,
            backingCallIn: secretsWalletsCountCancellable,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(numberOfItems):
                self?.presenter?.didReceive(numberOfWalletsWithSecrets: numberOfItems)
            case let .failure(error):
                self?.presenter?.didReceive(error: .secretsCounter(error))
            }
        }
    }
}
