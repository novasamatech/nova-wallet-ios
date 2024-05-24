import Foundation

protocol CloudBackupSyncConfirming {
    func cloudBackup(
        mediator: CloudBackupSyncMediating,
        didRequestConfirmation changes: CloudBackupSyncResult.Changes
    )
    
    func cloudBackup(
        mediator: CloudBackupSyncMediating,
        didFailToApply changes: CloudBackupSyncResult.Changes,
        error: Error
    )
}

protocol CloudBackupSyncMediating {
    var confirmationDelegate: CloudBackupSyncConfirming? { get set }
    
    func setup(with syncFacade: CloudBackupSyncFacadeProtocol)
    func approveCurrentChanges()
}

/**
 *  The class is designed to connect sync logic with UI presentations and changes application. It must be called from the main queue.
 *  To start one needs to set confirmationDelegate delegate and setup sync facade via corresponding method.
 */
final class CloudBackupSyncMediator {
    private let eventCenter: EventCenterProtocol
    private let selectedWalletSettings: SelectedWalletSettings
    private let cloudBackupApplyFactory: CloudBackupUpdateApplicationFactoryProtocol
    private let operationQueue: OperationQueue
    private let logger: LoggerProtocol
    private var syncFacade: CloudBackupSyncFacadeProtocol?
    
    private var pendingChanges: CloudBackupSyncResult.Changes?
    
    var confirmationDelegate: CloudBackupSyncConfirming?
    
    init(
        eventCenter: EventCenterProtocol,
        selectedWalletSettings: SelectedWalletSettings,
        cloudBackupApplyFactory: CloudBackupUpdateApplicationFactoryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.eventCenter = eventCenter
        self.selectedWalletSettings = selectedWalletSettings
        self.cloudBackupApplyFactory = cloudBackupApplyFactory
        self.operationQueue = operationQueue
        self.logger = logger
    }
    
    private func clearCurrentState() {
        syncFacade?.unsubscribeState(self)
        syncFacade = nil
        
        eventCenter.remove(observer: self)
    }
    
    private func setupCurrentState() {
        guard let syncFacade else {
            return
        }
        
        eventCenter.add(observer: self, dispatchIn: .main)
        
        syncFacade.subscribeState(self, notifyingIn: .main) { [weak self] state in
            self?.logger.debug("Backup state: \(state)")

            switch state {
            case .disabled, .unavailable:
                break
            case let .enabled(cloudBackupSyncResult, _):
                guard case let .changes(changes) = cloudBackupSyncResult else {
                    return
                }

                self?.handleNew(changes: changes)
            }
        }
    }
    
    private func handleNew(changes: CloudBackupSyncResult.Changes) {
        guard changes != pendingChanges else {
            return
        }
        
        if let pendingChanges else {
            // better not allow to apply several changes concurrently but try on the next trigger
            logger.warning("Recieved new changes while processing previous one: \(changes) \(pendingChanges)")
            return
        }
        
        pendingChanges = changes
        
        if changes.isCritical {
            confirmationDelegate?.cloudBackup(
                mediator: self,
                didRequestConfirmation: changes
            )
        } else {
            applyCurrentChanges()
        }
    }
    
    private func applyCurrentChanges() {
        guard let pendingChanges else {
            logger.warning("No current changes to apply")
            return
        }
        
        let wrapper = backupApplicationFactory.createUpdateApplyOperation(for: pendingChanges)

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            guard let self else {
                return
            }
            
            pendingChanges = nil
            
            if case let .failure(error) = result {
                logger.error("Unexpected cloud apply error: \(error)")
                confirmationDelegate?.cloudBackup(
                    mediator: self,
                    didFailToApply: changes,
                    error: error
                )
            }
        }
    }
}

extension CloudBackupSyncMediator: CloudBackupSyncMediating {
    func setup(with syncFacade: CloudBackupSyncFacadeProtocol) {
        clearCurrentState()
        
        self.syncFacade = syncFacade
        
        setupCurrentState()
    }
    
    func approveCurrentChanges() {
        applyCurrentChanges()
    }
}

extension CloudBackupSyncMediator: EventVisitorProtocol {
    func processChainAccountChanged(event: ChainAccountChanged) {
        syncFacade?.syncUp()
    }
    
    func processSelectedAccountChanged(event: SelectedAccountChanged) {
        syncFacade?.syncUp()
    }
    
    func processAccountsRemoved(event: AccountsRemovedManually) {
        syncFacade?.syncUp()
    }
    
    func processSelectedUsernameChanged(event: SelectedUsernameChanged) {
        syncFacade?.syncUp()
    }
}
