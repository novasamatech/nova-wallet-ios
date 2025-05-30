import UIKit
import Operation_iOS
import Keystore_iOS

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

    init(
        pushNotificationsFacade: PushNotificationsServiceFacadeProtocol,
        settingsLocalSubscriptionFactory: SettingsLocalSubscriptionFactoryProtocol,
        localPushSettingsFactory: PushNotificationSettingsFactoryProtocol,
        selectedWallet: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol
    ) {
        self.pushNotificationsFacade = pushNotificationsFacade
        self.settingsLocalSubscriptionFactory = settingsLocalSubscriptionFactory
        self.localPushSettingsFactory = localPushSettingsFactory
        self.chainRegistry = chainRegistry
        self.selectedWallet = selectedWallet
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
            if settings == nil {
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

    func provideSettings() {
        switch localSettings {
        case .undefined:
            return
        case let .defined(settings):
            guard let settings = settings else {
                return
            }
            presenter?.didReceive(settings: settings)
        }
    }
}

extension NotificationsManagementInteractor: NotificationsManagementInteractorInputProtocol {
    func setup() {
        subscribeToSettings()
        subscribeToTopicsSettings()
        provideNotificationsStatus()
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
            let settings = changes.reduceToLastChange() ?? .init(topics: .init())
            presenter?.didReceive(topicsSettings: settings)
        case let .failure(error):
            presenter?.didReceive(error: .settingsSubscription(error))
        }
    }
}
