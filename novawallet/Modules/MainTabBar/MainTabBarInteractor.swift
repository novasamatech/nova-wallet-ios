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

    private func showPushNotificationsSetupIfNeeded() {
        if !settingsManager.notificationsSetupSeen {
            securedLayer.scheduleExecutionIfAuthorized { [weak self] in
                self?.presenter?.didRequestPushNotificationsSetupOpen()
            }
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

        if let pendingScreen = screenOpenService.consumePendingScreenOpen() {
            presenter?.didRequestScreenOpen(pendingScreen)
        }

        if let pushPendingScreen = pushScreenOpenService.consumePendingScreenOpen() {
            presenter?.didRequestPushScreenOpen(pushPendingScreen)
        }

        showPushNotificationsSetupIfNeeded()

        cloudBackupMediator.setup(with: self)
    }

    func setPushNotificationsSetupScreenSeen() {
        settingsManager.notificationsSetupSeen = true
    }
}

extension MainTabBarInteractor: EventVisitorProtocol {
    func processSelectedAccountChanged(event _: SelectedAccountChanged) {
        serviceCoordinator.updateOnWalletSelectionChange()
    }

    func processAccountsChanged(event: AccountsChanged) {
        serviceCoordinator.updateOnWalletChange(for: event.method)
    }

    func processChainAccountChanged(event: ChainAccountChanged) {
        serviceCoordinator.updateOnWalletChange(for: event.method)
    }

    func processAccountsRemoved(event _: AccountsRemovedManually) {
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

extension MainTabBarInteractor: CloudBackupSyncConfirming {
    func cloudBackup(
        mediator _: CloudBackupSyncMediating,
        didRequestConfirmation changes: CloudBackupSyncResult.Changes
    ) {
        securedLayer.scheduleExecutionIfAuthorized { [weak self] in
            self?.presenter?.didRequestReviewCloud(changes: changes)
        }
    }

    func cloudBackupDidFailToApplyChanges(
        mediator _: CloudBackupSyncMediating,
        error: Error
    ) {
        securedLayer.scheduleExecutionIfAuthorized { [weak self] in
            self?.presenter?.didFailApplyingCloudChanges(error: error)
        }
    }
}
