import Foundation
import Keystore_iOS
import SubstrateSdk
import Foundation_iOS

final class MainTabBarInteractor: AnyProviderAutoCleaning {
    weak var presenter: MainTabBarInteractorOutputProtocol?

    let applicationHandler: ApplicationHandlerProtocol
    let eventCenter: EventCenterProtocol
    let secretImportService: SecretImportServiceProtocol
    let walletMigrationService: WalletMigrationServiceProtocol
    let screenOpenService: ScreenOpenServiceProtocol
    let preSyncServiceCoodrinator: PreSyncServiceCoordinatorProtocol
    let serviceCoordinator: ServiceCoordinatorProtocol
    let securedLayer: SecurityLayerServiceProtocol
    let inAppUpdatesService: SyncServiceProtocol
    let notificationsPromoService: MultisigNotificationsPromoServiceProtocol
    let pushScreenOpenService: PushNotificationOpenScreenFacadeProtocol
    let cloudBackupMediator: CloudBackupSyncMediating
    let settingsManager: SettingsManagerProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    let onLaunchQueue = OnLaunchActionsQueue(
        possibleActions: [
            OnLaunchAction.PushNotificationsSetup(),
            OnLaunchAction.AHMInfoSetup(),
            OnLaunchAction.MultisigNotificationsPromo()
        ]
    )

    deinit {
        stopServices()
    }

    init(
        applicationHandler: ApplicationHandlerProtocol,
        eventCenter: EventCenterProtocol,
        preSyncServiceCoodrinator: PreSyncServiceCoordinatorProtocol,
        serviceCoordinator: ServiceCoordinatorProtocol,
        secretImportService: SecretImportServiceProtocol,
        walletMigrationService: WalletMigrationServiceProtocol,
        screenOpenService: ScreenOpenServiceProtocol,
        notificationsPromoService: MultisigNotificationsPromoServiceProtocol,
        pushScreenOpenService: PushNotificationOpenScreenFacadeProtocol,
        cloudBackupMediator: CloudBackupSyncMediating,
        securedLayer: SecurityLayerServiceProtocol,
        inAppUpdatesService: SyncServiceProtocol,
        settingsManager: SettingsManagerProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.applicationHandler = applicationHandler
        self.eventCenter = eventCenter
        self.secretImportService = secretImportService
        self.walletMigrationService = walletMigrationService
        self.screenOpenService = screenOpenService
        self.notificationsPromoService = notificationsPromoService
        self.pushScreenOpenService = pushScreenOpenService
        self.cloudBackupMediator = cloudBackupMediator
        self.preSyncServiceCoodrinator = preSyncServiceCoodrinator
        self.serviceCoordinator = serviceCoordinator
        self.securedLayer = securedLayer
        self.inAppUpdatesService = inAppUpdatesService
        self.settingsManager = settingsManager
        self.operationQueue = operationQueue
        self.logger = logger

        self.inAppUpdatesService.setup()

        startServices()
    }
}

// MARK: - Private

private extension MainTabBarInteractor {
    func startServices() {
        let preSyncSetupWrapper = preSyncServiceCoodrinator.setup()

        execute(
            wrapper: preSyncSetupWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case .success:
                self?.serviceCoordinator.setup()
                self?.inAppUpdatesService.syncUp()
                self?.applicationHandler.delegate = self
            case .failure:
                self?.logger.error("Failed on setup pre sync services")
            }
        }
    }

    func stopServices() {
        preSyncServiceCoodrinator.throttle()
        serviceCoordinator.throttle()
        inAppUpdatesService.stopSyncUp()
    }

    func suggestSecretImportIfNeeded() {
        guard let definition = secretImportService.definition else {
            return
        }

        switch definition {
        case .keystore:
            presenter?.didRequestImportAccount(source: .keystore)
        case .mnemonic:
            presenter?.didRequestImportAccount(source: .mnemonic(.appDefault))
        }
    }

    func showPushNotificationsSetupOrNextAction() {
        if !settingsManager.notificationsSetupSeen {
            securedLayer.scheduleExecutionIfAuthorized { [weak self] in
                self?.presenter?.didRequestPushNotificationsSetupOpen()
            }
        } else {
            onLaunchQueue.runNext()
        }
    }

    func showAhmInfoOrNextAction() {
        securedLayer.scheduleExecutionIfAuthorized { [weak self] in
            self?.showAhmInfoOrNext { self?.onLaunchQueue.runNext() }
        }
    }

    func setupNotificationPromoObserver() {
        notificationsPromoService.add(
            observer: self,
            sendStateOnSubscription: true,
            queue: .main
        ) { [weak self] _, newState in
            guard let newState, case let .requestingShow(params) = newState else {
                return
            }

            self?.presenter?.didRequestMultisigNotificationsPromoOpen(with: params)
        }
    }

    func setupMultisigNotificationPromoOrNextAction() {
        securedLayer.scheduleExecutionIfAuthorized { [weak self] in
            self?.setupNotificationPromoObserver()
            self?.onLaunchQueue.runNext()
        }
    }

    func showAhmInfoOrNext(nextOnLaunchClosure: (() -> Void)? = nil) {
        let wrapper = preSyncServiceCoodrinator.ahmInfoService.fetchPassedMigrationsInfo()

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(info):
                guard !info.isEmpty else {
                    nextOnLaunchClosure?()
                    return
                }
                self?.presenter?.didRequestAHMInfoOpen(with: info)
            case let .failure(error):
                self?.logger.error("Error fetching AHM info: \(error)")
            }

            nextOnLaunchClosure?()
        }
    }

    func subscribeCloudSyncMonitor() {
        cloudBackupMediator.subscribeSyncMonitorStatus(for: self) { [weak self] oldStatus, newStatus in
            self?.securedLayer.scheduleExecutionIfAuthorized {
                self?.presenter?.didReceiveCloudSync(status: newStatus)
                self?.checkNeededSync(for: oldStatus, newStatus: newStatus)
            }
        }
    }

    func checkNeededSync(
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

    func handleWalletMigration(message: WalletMigrationMessage) {
        switch message {
        case let .start(content):
            presenter?.didRequestWalletMigration(with: content)
        default:
            break
        }
    }
}

// MARK: - MainTabBarInteractorInputProtocol

extension MainTabBarInteractor: MainTabBarInteractorInputProtocol {
    func setup() {
        eventCenter.add(observer: self, dispatchIn: .main)
        secretImportService.add(observer: self)
        walletMigrationService.addObserver(self)

        suggestSecretImportIfNeeded()

        screenOpenService.delegate = self
        pushScreenOpenService.delegate = self

        cloudBackupMediator.setup(with: self)
        subscribeCloudSyncMonitor()
        cloudBackupMediator.sync(for: .unknown)

        onLaunchQueue.delegate = self

        if
            let message = walletMigrationService.consumePendingMessage(),
            case let .start(content) = message {
            presenter?.didRequestWalletMigration(with: content)
        } else if let pendingScreen = screenOpenService.consumePendingScreenOpen() {
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

// MARK: - EventVisitorProtocol

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

// MARK: - SecretImportObserver

extension MainTabBarInteractor: SecretImportObserver {
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

// MARK: - WalletMigrationObserver

extension MainTabBarInteractor: WalletMigrationObserver {
    func didReceiveMigration(message: WalletMigrationMessage) {
        securedLayer.scheduleExecutionIfAuthorized { [weak self] in
            self?.handleWalletMigration(message: message)
        }
    }
}

// MARK: - ScreenOpenDelegate

extension MainTabBarInteractor: ScreenOpenDelegate {
    func didAskScreenOpen(_ screen: UrlHandlingScreen) {
        securedLayer.scheduleExecutionIfAuthorized { [weak self] in
            self?.presenter?.didRequestScreenOpen(screen)
        }
    }
}

// MARK: - PushNotificationOpenDelegate

extension MainTabBarInteractor: PushNotificationOpenDelegate {
    func didAskScreenOpen(_ screen: PushNotification.OpenScreen) {
        securedLayer.scheduleExecutionIfAuthorized { [weak self] in
            self?.presenter?.didRequestPushScreenOpen(screen)
        }
    }
}

// MARK: - CloudBackupSynсUIPresenting

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

// MARK: - OnLaunchActionsQueueDelegate

extension MainTabBarInteractor: OnLaunchActionsQueueDelegate {
    func onLaunchProccessPushNotificationsSetup(_: OnLaunchAction.PushNotificationsSetup) {
        showPushNotificationsSetupOrNextAction()
    }

    func onLaunchProcessMultisigNotificationPromo(_: OnLaunchAction.MultisigNotificationsPromo) {
        setupMultisigNotificationPromoOrNextAction()
    }

    func onLaunchProcessAHMInfoSetup(_: OnLaunchAction.AHMInfoSetup) {
        showAhmInfoOrNextAction()
    }
}

// MARK: - ApplicationHandlerDelegate

extension MainTabBarInteractor: ApplicationHandlerDelegate {
    func didReceiveDidBecomeActive(notification _: Notification) {
        let updateServicesWrapper = preSyncServiceCoodrinator.updateOnAppBecomeActive()

        execute(
            wrapper: updateServicesWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case .success:
                self?.showAhmInfoOrNext()
            case .failure:
                self?.logger.error("Failed on update pre sync services")
            }
        }
    }
}
