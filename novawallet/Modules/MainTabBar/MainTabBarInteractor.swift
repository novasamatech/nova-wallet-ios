import Foundation
import SoraKeystore

import SubstrateSdk

final class MainTabBarInteractor {
    weak var presenter: MainTabBarInteractorOutputProtocol?

    let eventCenter: EventCenterProtocol
    let keystoreImportService: KeystoreImportServiceProtocol
    let screenOpenService: ScreenOpenServiceProtocol
    let serviceCoordinator: ServiceCoordinatorProtocol
    let securedLayer: SecurityLayerServiceProtocol
    let inAppUpdatesService: SyncServiceProtocol
    let pushScreenOpenService: PushNotificationOpenScreenFacadeProtocol
    let cloudBackupMediator: CloudBackupSyncMediating
    let settingsManager: SettingsManagerProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    let onLaunchQueue = OnLaunchActionsQueue(
        possibleActions: [
            OnLaunchAction.PushNotificationsSetup()
        ]
    )

    deinit {
        stopServices()
    }

    init(
        eventCenter: EventCenterProtocol,
        serviceCoordinator: ServiceCoordinatorProtocol,
        keystoreImportService: KeystoreImportServiceProtocol,
        screenOpenService: ScreenOpenServiceProtocol,
        pushScreenOpenService: PushNotificationOpenScreenFacadeProtocol,
        cloudBackupMediator: CloudBackupSyncMediating,
        securedLayer: SecurityLayerServiceProtocol,
        inAppUpdatesService: SyncServiceProtocol,
        settingsManager: SettingsManagerProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.eventCenter = eventCenter
        self.keystoreImportService = keystoreImportService
        self.screenOpenService = screenOpenService
        self.pushScreenOpenService = pushScreenOpenService
        self.cloudBackupMediator = cloudBackupMediator
        self.serviceCoordinator = serviceCoordinator
        self.securedLayer = securedLayer
        self.inAppUpdatesService = inAppUpdatesService
        self.settingsManager = settingsManager
        self.operationQueue = operationQueue
        self.logger = logger

        self.inAppUpdatesService.setup()

        startServices()
    }

    private func startServices() {
        serviceCoordinator.setup()
        inAppUpdatesService.syncUp()
    }

    private func stopServices() {
        serviceCoordinator.throttle()
        inAppUpdatesService.stopSyncUp()
    }

    private func suggestSecretImportIfNeeded() {
        guard let definition = keystoreImportService.definition else {
            return
        }

        switch definition {
        case .keystore:
            presenter?.didRequestImportAccount(source: .keystore)
        case .mnemonic:
            presenter?.didRequestImportAccount(source: .mnemonic)
        }
    }

    private func showPushNotificationsSetupOrNextAction() {
        if !settingsManager.notificationsSetupSeen {
            securedLayer.scheduleExecutionIfAuthorized { [weak self] in
                self?.presenter?.didRequestPushNotificationsSetupOpen()
            }
        } else {
            onLaunchQueue.runNext()
        }
    }

    private func subscribeCloudSyncMonitor() {
        cloudBackupMediator.subscribeSyncMonitorStatus(for: self) { [weak self] oldStatus, newStatus in
            self?.presenter?.didReceiveCloudSync(status: newStatus)
            self?.checkNeededSync(for: oldStatus, newStatus: newStatus)
        }
    }

    private func checkNeededSync(
        for oldStatus: CloudBackupSyncMonitorStatus?,
        newStatus: CloudBackupSyncMonitorStatus?
    ) {
        guard let oldStatus, let newStatus else {
            return
        }

        if oldStatus.isDowndloading, !newStatus.isSyncing {
            cloudBackupMediator.sync(for: .unknown)
        }
    }
}

extension MainTabBarInteractor: MainTabBarInteractorInputProtocol {
    func setup() {
        eventCenter.add(observer: self, dispatchIn: .main)
        keystoreImportService.add(observer: self)

        suggestSecretImportIfNeeded()

        screenOpenService.delegate = self
        pushScreenOpenService.delegate = self

        cloudBackupMediator.setup(with: self)
        subscribeCloudSyncMonitor()
        cloudBackupMediator.sync(for: .unknown)

        onLaunchQueue.delegate = self

        if let pendingScreen = screenOpenService.consumePendingScreenOpen() {
            presenter?.didRequestScreenOpen(pendingScreen)
        } else if let pushPendingScreen = pushScreenOpenService.consumePendingScreenOpen() {
            presenter?.didRequestPushScreenOpen(pushPendingScreen)
        } else {
            onLaunchQueue.runNext()
        }
    }

    func setPushNotificationsSetupScreenSeen() {
        settingsManager.notificationsSetupSeen = true
    }

    func requestNextOnLaunchAction() {
        onLaunchQueue.runNext()
    }
}

extension MainTabBarInteractor: EventVisitorProtocol {
    func processSelectedWalletChanged(event _: SelectedWalletSwitched) {
        serviceCoordinator.updateOnWalletSelectionChange()
    }

    func processWalletImported(event _: NewWalletImported) {
        serviceCoordinator.updateOnWalletChange(for: .byUserManually)
    }

    func processNewWalletCreated(event _: NewWalletCreated) {
        serviceCoordinator.updateOnWalletChange(for: .byUserManually)
    }

    func processChainAccountChanged(event _: ChainAccountChanged) {
        serviceCoordinator.updateOnWalletChange(for: .byUserManually)
    }

    func processWalletsChanged(event: WalletsChanged) {
        serviceCoordinator.updateOnWalletChange(for: event.source)
    }

    func processWalletRemoved(event _: WalletRemoved) {
        serviceCoordinator.updateOnWalletRemove()
    }
}

extension MainTabBarInteractor: KeystoreImportObserver {
    func didUpdateDefinition(from _: SecretImportDefinition?) {
        securedLayer.scheduleExecutionIfAuthorized { [weak self] in
            self?.suggestSecretImportIfNeeded()
        }
    }

    func didReceiveError(secretImportError error: Error & ErrorContentConvertible) {
        securedLayer.scheduleExecutionIfAuthorized { [weak self] in
            self?.presenter?.didRequestScreenOpen(.error(.content(error)))
        }
    }
}

extension MainTabBarInteractor: ScreenOpenDelegate {
    func didAskScreenOpen(_ screen: UrlHandlingScreen) {
        securedLayer.scheduleExecutionIfAuthorized { [weak self] in
            self?.presenter?.didRequestScreenOpen(screen)
        }
    }
}

extension MainTabBarInteractor: PushNotificationOpenDelegate {
    func didAskScreenOpen(_ screen: PushNotification.OpenScreen) {
        securedLayer.scheduleExecutionIfAuthorized { [weak self] in
            self?.presenter?.didRequestPushScreenOpen(screen)
        }
    }
}

extension MainTabBarInteractor: CloudBackupSynсUIPresenting {
    func cloudBackup(
        mediator _: CloudBackupSyncMediating,
        didRequestConfirmation changes: CloudBackupSyncResult.Changes
    ) {
        securedLayer.scheduleExecutionIfAuthorized { [weak self] in
            self?.presenter?.didRequestReviewCloud(changes: changes)
        }
    }

    func cloudBackup(mediator _: CloudBackupSyncMediating, didFound issue: CloudBackupSyncResult.Issue) {
        securedLayer.scheduleExecutionIfAuthorized { [weak self] in
            self?.presenter?.didFoundCloudBackup(issue: issue)
        }
    }

    func cloudBackupDidSync(mediator _: CloudBackupSyncMediating, for purpose: CloudBackupSynсPurpose) {
        presenter?.didSyncCloudBackup(on: purpose)
    }
}

extension MainTabBarInteractor: OnLaunchActionsQueueDelegate {
    func onLaunchProccessPushNotificationsSetup(_: OnLaunchAction.PushNotificationsSetup) {
        showPushNotificationsSetupOrNextAction()
    }
}
