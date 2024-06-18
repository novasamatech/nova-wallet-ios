import Foundation

enum CloudBackupSynсPurpose {
    case createWallet
    case importWallet
    case removeWallet
    case addChainAccount
    case unknown
}

protocol CloudBackupSynсUIPresenting: AnyObject {
    func cloudBackup(
        mediator: CloudBackupSyncMediating,
        didRequestConfirmation changes: CloudBackupSyncResult.Changes
    )

    func cloudBackup(
        mediator: CloudBackupSyncMediating,
        didFound issue: CloudBackupSyncResult.Issue
    )

    func cloudBackupDidSync(mediator: CloudBackupSyncMediating, for purpose: CloudBackupSynсPurpose)
}

protocol CloudBackupSyncMediating {
    var syncService: CloudBackupSyncServiceProtocol { get }

    func setup(with uiPresenter: CloudBackupSynсUIPresenting)
    func approveCurrentChanges()

    func enablePresenterNotifications()
    func disablePresenterNotifications()

    func sync(for purpose: CloudBackupSynсPurpose)
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

    private var isPresenterNotificationsEnabled: Bool = true

    private var syncPurpose: CloudBackupSynсPurpose = .unknown

    private var backupSyncMonitor: CloudBackupSyncMonitoring?

    weak var uiPresenter: CloudBackupSynсUIPresenting?

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

    private func setupBackupMonitorIfNeeded() {
        guard backupSyncMonitor == nil else {
            return
        }

        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 1

        let monitor = ICloudBackupSyncMonitor(
            filename: CloudBackup.walletsFilename,
            operationQueue: operationQueue,
            notificationCenter: NotificationCenter.default,
            logger: logger
        )

        backupSyncMonitor = monitor

        monitor.start(notifyingIn: .main) { [weak self] status in
            self?.logger.debug("Status: \(status)")
        }
    }

    private func clearBackupMonitorIfNeeded() {
        guard let backupSyncMonitor else {
            return
        }

        self.backupSyncMonitor = nil
        backupSyncMonitor.stop()
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

    func notifyPresenterWithConfirmationIfNeeded(for changes: CloudBackupSyncResult.Changes) {
        guard isPresenterNotificationsEnabled else {
            return
        }

        uiPresenter?.cloudBackup(
            mediator: self,
            didRequestConfirmation: changes
        )
    }

    func notifyPresenterAboutIssueIfNeeded(_ issue: CloudBackupSyncResult.Issue) {
        guard isPresenterNotificationsEnabled else {
            return
        }

        uiPresenter?.cloudBackup(mediator: self, didFound: issue)
    }

    func notifyPresenterAboutSyncCompletion() {
        let purpose = syncPurpose
        syncPurpose = .unknown

        guard isPresenterNotificationsEnabled else {
            return
        }

        uiPresenter?.cloudBackupDidSync(mediator: self, for: purpose)
    }

    private func handleNew(state: CloudBackupSyncState) {
        switch state {
        case .disabled, .unavailable:
            clearBackupMonitorIfNeeded()

            syncPurpose = .unknown
            logger.debug("No need to process disabled or unavailable")
        case let .enabled(cloudBackupSyncResult, _):
            setupBackupMonitorIfNeeded()

            guard let cloudBackupSyncResult = cloudBackupSyncResult else {
                return
            }

            handleSync(result: cloudBackupSyncResult)
        }
    }

    private func handleSync(result: CloudBackupSyncResult) {
        switch result {
        case .noUpdates:
            syncPurpose = .unknown
            logger.debug("No sync updates")
        case let .changes(changes):
            handleNew(changes: changes)
        case let .issue(issue):
            syncPurpose = .unknown
            notifyPresenterAboutIssueIfNeeded(issue)
        }
    }

    private func handleNew(changes: CloudBackupSyncResult.Changes) {
        if changes.isDestructive {
            syncPurpose = .unknown
            notifyPresenterWithConfirmationIfNeeded(for: changes)
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

                notifyPresenterAboutSyncCompletion()

                emitEvents(
                    for: appliedChanges,
                    selectedWalletBeforeUpdate: selectedWalletBeforeUpdate
                )
            case let .failure(error):
                self.logger.error("Unexpected changes apply error \(error)")
            }
        }
    }

    private func emitEvents(
        for appliedChanges: CloudBackupSyncResult.Changes,
        selectedWalletBeforeUpdate: MetaAccountModel?
    ) {
        let selectedWallet = selectedWalletSettings.hasValue ? selectedWalletSettings.value : nil
        let walletSwitched = selectedWalletBeforeUpdate?.identifier != selectedWallet?.identifier

        switch appliedChanges {
        case let .updateLocal(local):
            if !local.changes.isEmpty {
                eventCenter.notify(with: WalletsChanged(source: .byCloudBackup))
            }
        case let .updateByUnion(updateByUnion):
            if !updateByUnion.addingWallets.isEmpty {
                eventCenter.notify(with: WalletsChanged(source: .byCloudBackup))
            }
        case .updateRemote:
            break
        }

        if walletSwitched {
            eventCenter.notify(with: SelectedWalletSwitched())
        } else if selectedWalletBeforeUpdate?.name != selectedWallet?.name {
            eventCenter.notify(with: WalletNameChanged(isSelectedWallet: true))
        }
    }
}

extension CloudBackupSyncMediator: CloudBackupSyncMediating {
    func setup(with uiPresenter: CloudBackupSynсUIPresenting) {
        self.uiPresenter = uiPresenter

        setupCurrentState()
    }

    func approveCurrentChanges() {
        syncPurpose = .unknown
        applyChanges()
    }

    func throttle() {
        uiPresenter = nil

        clearCurrentState()

        clearBackupMonitorIfNeeded()
    }

    func enablePresenterNotifications() {
        isPresenterNotificationsEnabled = true
    }

    func disablePresenterNotifications() {
        isPresenterNotificationsEnabled = false
    }

    func sync(for purpose: CloudBackupSynсPurpose) {
        syncPurpose = purpose
        syncService.syncUp()
    }
}

extension CloudBackupSyncMediator: EventVisitorProtocol {
    func processNewWalletCreated(event _: NewWalletCreated) {
        sync(for: .createWallet)
    }

    func processWalletImported(event _: NewWalletImported) {
        sync(for: .importWallet)
    }

    func processWalletRemoved(event _: WalletRemoved) {
        sync(for: .removeWallet)
    }

    func processChainAccountChanged(event _: ChainAccountChanged) {
        sync(for: .addChainAccount)
    }

    func processWalletsChanged(event: WalletsChanged) {
        switch event.source {
        case .byCloudBackup, .byUserManually:
            sync(for: .unknown)
        case .byProxyService:
            break
        }
    }

    func processWalletNameChanged(event _: WalletNameChanged) {
        sync(for: .unknown)
    }
}
