import UIKit
import RobinHood
import SoraKeystore

final class NotificationsManagementInteractor: AnyProviderAutoCleaning {
    weak var presenter: NotificationsManagementInteractorOutputProtocol?
    let settingsLocalSubscriptionFactory: SettingsLocalSubscriptionFactoryProtocol
    let pushNotificationsFacade: PushNotificationsServiceFacadeProtocol
    let localPushSettingsFactory: PushNotificationSettingsFactoryProtocol
    let selectedWallet: MetaAccountModel
    let chainRegistry: ChainRegistryProtocol

    private var settingsProvider: StreamableProvider<Web3Alert.LocalSettings>?
    private var topicsSettingsProvider: StreamableProvider<PushNotification.TopicSettings>?
    private var notificationStatus: PushNotificationsStatus? {
        didSet {
            createDefaultSettingsIfNeeded()
        }
    }

    private var localSettings: UncertainStorage<Web3Alert.LocalSettings?> = .undefined {
        didSet {
            createDefaultSettingsIfNeeded()
        }
    }

    private var metaAccounts: [MetaAccountModel.Id: MetaAccountModel] = [:]

    private let walletsRepository: AnyDataProviderRepository<MetaAccountModel>
    private let operationQueue: OperationQueue
    private let callStore = CancellableCallStore()

    init(
        pushNotificationsFacade: PushNotificationsServiceFacadeProtocol,
        settingsLocalSubscriptionFactory: SettingsLocalSubscriptionFactoryProtocol,
        localPushSettingsFactory: PushNotificationSettingsFactoryProtocol,
        selectedWallet: MetaAccountModel,
        walletsRepository: AnyDataProviderRepository<MetaAccountModel>,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue
    ) {
        self.pushNotificationsFacade = pushNotificationsFacade
        self.settingsLocalSubscriptionFactory = settingsLocalSubscriptionFactory
        self.localPushSettingsFactory = localPushSettingsFactory
        self.chainRegistry = chainRegistry
        self.selectedWallet = selectedWallet
        self.walletsRepository = walletsRepository
        self.operationQueue = operationQueue
    }

    private func subscribeToSettings() {
        clear(streamableProvider: &settingsProvider)
        settingsProvider = subscribeToPushSettings()
    }

    private func subscribeToTopicsSettings() {
        clear(streamableProvider: &topicsSettingsProvider)
        topicsSettingsProvider = subscribeToTopicsSettings()
    }

    private func provideNotificationsStatus() {
        pushNotificationsFacade.subscribeStatus(self) { [weak self] _, status in
            self?.notificationStatus = status
            self?.presenter?.didReceive(notificationStatus: status)
        }
    }

    private func createDefaultSettingsIfNeeded() {
        switch localSettings {
        case .undefined:
            return
        case let .defined(settings):
            if settings == nil, notificationStatus == .denied {
                chainRegistry.chainsSubscribe(
                    self,
                    runningInQueue: .main
                ) { [weak self] changes in
                    guard let self = self else {
                        return
                    }
                    self.chainRegistry.chainsUnsubscribe(self)
                    let chains = changes.mergeToDict([String: ChainModel]())
                    let defaultSettings = self.localPushSettingsFactory.createWalletSettings(
                        for: self.selectedWallet,
                        chains: chains
                    )
                    self.localSettings = .defined(defaultSettings)
                    self.provideSettings()
                }
            }
        }
    }

    func fetchWallets() {
        let fetchWalletsOperation = walletsRepository.fetchAllOperation(with: .init())
        execute(
            operation: fetchWalletsOperation,
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(metaAccounts):
                self?.metaAccounts = metaAccounts.reduce(into: [MetaAccountModel.Id: MetaAccountModel]()) {
                    $0[$1.metaId] = $1
                }
                self?.provideSettings()
            case let .failure(error):
                self?.presenter?.didReceive(error: .fetchMetaAccounts(error))
            }
        }
    }

    func provideSettings() {
        switch localSettings {
        case .undefined:
            return
        case let .defined(settings):
            guard let settings = settings, !metaAccounts.isEmpty else {
                return
            }
            let existingWallets = settings.wallets.filter { metaAccounts[$0.metaId] != nil }
            let settingsWithExistingWallets = settings.with(wallets: existingWallets)
            localSettings = .defined(settingsWithExistingWallets)
            presenter?.didReceive(settings: settingsWithExistingWallets)
        }
    }
}

extension NotificationsManagementInteractor: NotificationsManagementInteractorInputProtocol {
    func setup() {
        subscribeToSettings()
        subscribeToTopicsSettings()
        provideNotificationsStatus()
        fetchWallets()
    }

    func save(
        settings: Web3Alert.LocalSettings,
        topics: PushNotification.TopicSettings,
        notificationsEnabled: Bool
    ) {
        let allSettings = PushNotification.AllSettings(
            notificationsEnabled: notificationsEnabled,
            accountBased: settings.settingCurrentDate(),
            topics: topics
        )

        pushNotificationsFacade.save(settings: allSettings) { [weak self] result in
            switch result {
            case .success:
                self?.presenter?.didReceiveSaveCompletion()
            case let .failure(error):
                self?.presenter?.didReceive(error: .save(error))
            }
        }
    }

    func remakeSubscription() {
        subscribeToSettings()
        subscribeToTopicsSettings()
    }

    func fetchMetaAccounts() {
        fetchWallets()
    }
}

extension NotificationsManagementInteractor: SettingsSubscriber, SettingsSubscriptionHandler {
    func handlePushNotificationsSettings(result: Result<[DataProviderChange<Web3Alert.LocalSettings>], Error>) {
        switch result {
        case let .success(changes):
            let lastChange = changes.reduceToLastChange()
            localSettings = .defined(lastChange)
            provideSettings()
        case let .failure(error):
            presenter?.didReceive(error: .settingsSubscription(error))
        }
    }

    func handleTopicsSettings(result: Result<[DataProviderChange<PushNotification.TopicSettings>], Error>) {
        switch result {
        case let .success(changes):
            if let settings = changes.reduceToLastChange() {
                presenter?.didReceive(topicsSettings: settings)
            }
        case let .failure(error):
            presenter?.didReceive(error: .settingsSubscription(error))
        }
    }
}
