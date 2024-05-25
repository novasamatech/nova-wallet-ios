import Foundation

protocol CloudBackupSyncConfirming: AnyObject {
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
    func updateState()
}

/**
 *  The class is designed to connect sync logic with UI presentations and changes application.
 *  It must be called from the main queue. To start one needs to set confirmationDelegate delegate
 *  and setup sync facade via corresponding method.
 */
final class CloudBackupSyncMediator {
    private let eventCenter: EventCenterProtocol
    private let selectedWalletSettings: SelectedWalletSettings
    private let cloudBackupApplyFactory: CloudBackupUpdateApplicationFactoryProtocol
    private let operationQueue: OperationQueue
    private let logger: LoggerProtocol
    private var syncFacade: CloudBackupSyncFacadeProtocol?

    private var pendingChanges: CloudBackupSyncResult.Changes?
    private var applyingChanges: Bool = false

    weak var confirmationDelegate: CloudBackupSyncConfirming?

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
            self?.handleNew(state: state)
        }
    }

    private func handleNew(state: CloudBackupSyncState) {
        switch state {
        case .disabled, .unavailable:
            logger.debug("No need to process disabled or unavailable")
        case let .enabled(cloudBackupSyncResult, _):
            guard case let .changes(changes) = cloudBackupSyncResult else {
                logger.debug("No changes to process")
                return
            }

            handleNew(changes: changes)
        }
    }

    private func handleNew(changes: CloudBackupSyncResult.Changes) {
        guard changes != pendingChanges else {
            return
        }

        if let pendingChanges {
            // better not allow to apply several changes concurrently but try on the next trigger
            logger.warning("Recieved new changes while processing previous one: \(changes) \(pendingChanges)")
            return
        }

        pendingChanges = changes

        decideOnChanges()
    }

    private func decideOnChanges() {
        guard let pendingChanges else {
            return
        }

        if pendingChanges.isCritical {
            confirmationDelegate?.cloudBackup(
                mediator: self,
                didRequestConfirmation: pendingChanges
            )
        } else {
            applyCurrentChanges()
        }
    }

    private func applyCurrentChanges() {
        guard let changes = pendingChanges else {
            logger.warning("No current changes to apply")
            return
        }

        guard applyingChanges else {
            logger.warning("Already applying changes")
            return
        }

        let wrapper = cloudBackupApplyFactory.createUpdateApplyOperation(for: changes)

        applyingChanges = true
        
        let selectedWalletBeforeUpdate = selectedWalletSettings.value

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            guard let self else {
                return
            }

            self.pendingChanges = nil
            self.applyingChanges = false
            
            switch result {
            case .success:
                logger.error("Cloud changes applied: \(changes)")
                emitEvents(
                    for: changes,
                    selectedWalletBeforeUpdate: selectedWalletBeforeUpdate
                )
            case let .failure(error):
                logger.error("Unexpected cloud apply error: \(error)")
                confirmationDelegate?.cloudBackup(
                    mediator: self,
                    didFailToApply: changes,
                    error: error
                )
            }
        }
    }
    
    private func emitEvents(
        for appliedChanges: CloudBackupSyncResult.Changes,
        selectedWalletBeforeUpdate: MetaAccountModel?
    ) {
        let selectedWallet = selectedWalletSettings.hasValue ? selectedWalletSettings.value : nil
        let walletSwitched = selectedWalletBeforeUpdate != selectedWallet
        
        switch appliedChanges {
        case let .updateLocal(local):
            if local.changes.hasChainAccountChanges {
                eventCenter.notify(with: ChainAccountChanged(method: .manually))
            }
            
            if local.changes.hasWalletRemoves {
                eventCenter.notify(with: AccountsRemovedManually())
            }
        case .updateRemote, .updateByUnion:
            break
        }
        
        if walletSwitched {
            eventCenter.notify(with: SelectedAccountChanged())
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

    func updateState() {
        if pendingChanges != nil {
            decideOnChanges()
        } else if let state = syncFacade?.getState() {
            handleNew(state: state)
        }
    }
}

extension CloudBackupSyncMediator: EventVisitorProtocol {
    func processChainAccountChanged(event _: ChainAccountChanged) {
        syncFacade?.syncUp()
    }

    func processSelectedAccountChanged(event _: SelectedAccountChanged) {
        syncFacade?.syncUp()
    }

    func processAccountsRemoved(event _: AccountsRemovedManually) {
        syncFacade?.syncUp()
    }

    func processSelectedUsernameChanged(event _: SelectedUsernameChanged) {
        syncFacade?.syncUp()
    }
}
