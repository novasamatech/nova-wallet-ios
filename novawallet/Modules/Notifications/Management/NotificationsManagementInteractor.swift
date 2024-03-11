import UIKit
import RobinHood
import SoraKeystore

final class NotificationsManagementInteractor: AnyProviderAutoCleaning {
    weak var presenter: NotificationsManagementInteractorOutputProtocol?
    let settingsLocalSubscriptionFactory: SettingsLocalSubscriptionFactoryProtocol
    let pushNotificationsFacade: PushNotificationsServiceFacadeProtocol

    private var settingsProvider: StreamableProvider<Web3Alert.LocalSettings>?
    private var topicsSettingsProvider: StreamableProvider<PushNotification.TopicSettings>?

    init(
        pushNotificationsFacade: PushNotificationsServiceFacadeProtocol,
        settingsLocalSubscriptionFactory: SettingsLocalSubscriptionFactoryProtocol
    ) {
        self.pushNotificationsFacade = pushNotificationsFacade
        self.settingsLocalSubscriptionFactory = settingsLocalSubscriptionFactory
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
            self?.presenter?.didReceive(notificationStatus: status)
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
            if let settings = changes.reduceToLastChange() {
                presenter?.didReceive(settings: settings)
            }
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
