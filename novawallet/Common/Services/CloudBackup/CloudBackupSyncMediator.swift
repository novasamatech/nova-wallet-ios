import Foundation

protocol CloudBackupSyncConfirming: AnyObject {
    func cloudBackup(
        mediator: CloudBackupSyncMediating,
        didRequestConfirmation changes: CloudBackupSyncResult.Changes
    )

    func cloudBackupDidFailToApplyChanges(
        mediator: CloudBackupSyncMediating,
        error: Error
    )
}

protocol CloudBackupSyncMediating {
    var syncService: CloudBackupSyncServiceProtocol { get }

    func setup(with confirmingDelegate: CloudBackupSyncConfirming)
    func approveCurrentChanges()
    func throttle()
}

/**
 *  The class is designed to connect sync logic with UI presentations and changes application.
 *  It must be called from the main queue. To start one needs to set confirmationDelegate delegate
 *  and setup sync facade via corresponding method.
 */
final class CloudBackupSyncMediator {
    let syncService: CloudBackupSyncServiceProtocol

    private let eventCenter: EventCenterProtocol
    private let selectedWalletSettings: SelectedWalletSettings
    private let operationQueue: OperationQueue
    private let logger: LoggerProtocol

    weak var confirmationDelegate: CloudBackupSyncConfirming?

    init(
        syncService: CloudBackupSyncServiceProtocol,
        eventCenter: EventCenterProtocol,
        selectedWalletSettings: SelectedWalletSettings,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.syncService = syncService
        self.eventCenter = eventCenter
        self.selectedWalletSettings = selectedWalletSettings
        self.operationQueue = operationQueue
        self.logger = logger
    }

    private func setupCurrentState() {
        eventCenter.add(observer: self, dispatchIn: .main)

        syncService.subscribeState(self, notifyingIn: .main) { [weak self] state in
            self?.logger.debug("Backup state: \(state)")
            self?.handleNew(state: state)
        }
    }

    private func clearCurrentState() {
        syncService.unsubscribeState(self)

        eventCenter.remove(observer: self)
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
        if changes.isDestructive {
            confirmationDelegate?.cloudBackup(
                mediator: self,
                didRequestConfirmation: changes
            )
        } else {
            applyChanges()
        }
    }

    private func applyChanges() {
        let selectedWalletBeforeUpdate = selectedWalletSettings.value

        syncService.applyChanges(notifyingIn: .main) { [weak self] result in
            guard let self else {
                return
            }

            switch result {
            case let .success(maybeAppliedChanges):
                guard let appliedChanges = maybeAppliedChanges else {
                    return
                }

                emitEvents(
                    for: appliedChanges,
                    selectedWalletBeforeUpdate: selectedWalletBeforeUpdate
                )
            case let .failure(error):
                confirmationDelegate?.cloudBackupDidFailToApplyChanges(mediator: self, error: error)
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
        } else if selectedWalletBeforeUpdate?.name != selectedWallet?.name {
            eventCenter.notify(with: SelectedUsernameChanged())
        }
    }
}

extension CloudBackupSyncMediator: CloudBackupSyncMediating {
    func setup(with confirmingDelegate: CloudBackupSyncConfirming) {
        confirmationDelegate = confirmingDelegate

        setupCurrentState()
    }

    func approveCurrentChanges() {
        applyChanges()
    }

    func throttle() {
        confirmationDelegate = nil

        clearCurrentState()
    }
}

extension CloudBackupSyncMediator: EventVisitorProtocol {
    func processChainAccountChanged(event _: ChainAccountChanged) {
        syncService.syncUp()
    }

    func processAccountsChanged(event _: AccountsChanged) {
        syncService.syncUp()
    }

    func processAccountsRemoved(event _: AccountsRemovedManually) {
        syncService.syncUp()
    }

    func processSelectedUsernameChanged(event _: SelectedUsernameChanged) {
        syncService.syncUp()
    }

    func processWalletNameChanged(event _: WalletNameChanged) {
        syncService.syncUp()
    }
}
