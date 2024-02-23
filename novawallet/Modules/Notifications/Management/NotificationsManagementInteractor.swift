import UIKit
import RobinHood
import SoraKeystore

final class NotificationsManagementInteractor: AnyProviderAutoCleaning {
    weak var presenter: NotificationsManagementInteractorOutputProtocol?
    let settingsLocalSubscriptionFactory: SettingsLocalSubscriptionFactoryProtocol
    let settingsManager: SettingsManagerProtocol
    let alertServiceFactory: Web3AlertsServicesFactoryProtocol

    private var settingsProvider: StreamableProvider<LocalPushSettings>?
    private var topicsSettingsProvider: StreamableProvider<LocalNotificationTopicSettings>?
    private var syncService: Web3AlertsSyncServiceProtocol?
    private var pushService: PushNotificationsServiceProtocol?
    private var topicService: TopicServiceProtocol?

    init(
        settingsLocalSubscriptionFactory: SettingsLocalSubscriptionFactoryProtocol,
        settingsManager: SettingsManagerProtocol,
        alertServiceFactory: Web3AlertsServicesFactoryProtocol
    ) {
        self.settingsLocalSubscriptionFactory = settingsLocalSubscriptionFactory
        self.settingsManager = settingsManager
        self.alertServiceFactory = alertServiceFactory
    }

    private func subscribeToSettings() {
        clear(streamableProvider: &settingsProvider)
        settingsProvider = subscribeToPushSettings()
    }

    private func subscribeToTopicsSettings() {
        clear(streamableProvider: &topicsSettingsProvider)
        topicsSettingsProvider = subscribeToTopicsSettings()
    }

    private func provideAnnouncementsFlag() {
        let isEnabled = settingsManager.announcements
        DispatchQueue.main.async {
            self.presenter?.didReceive(announcementsEnabled: isEnabled)
        }
    }

    private func provideNotificationsStatus() {
        if pushService == nil {
            pushService = alertServiceFactory.createPushNotificationsService()
        }

        pushService?.statusObservable.addObserver(with: self, sendStateOnSubscription: true) { [weak self] _, status in
            guard let status = status else {
                return
            }
            DispatchQueue.main.async {
                self?.presenter?.didReceive(notificationsEnabled: status == .on)
            }
        }
    }
}

extension NotificationsManagementInteractor: NotificationsManagementInteractorInputProtocol {
    func setup() {
        subscribeToSettings()
        subscribeToTopicsSettings()
        provideAnnouncementsFlag()
        provideNotificationsStatus()
    }

    func enableNotifications() {
        if pushService?.statusObservable.state == .denied {
            DispatchQueue.main.async {
                self.presenter?.didReceive(error: .notificationsDisabledInSettings)
            }
        }
    }

    func save(
        settings: LocalPushSettings,
        topics: LocalNotificationTopicSettings,
        notificationsEnabled: Bool,
        announcementsEnabled: Bool
    ) {
        if syncService == nil {
            syncService = alertServiceFactory.createSyncService()
        }

        let group = DispatchGroup()
        group.enter()
        group.enter()

        syncService?.save(settings: settings) { [weak self] in
            self?.settingsManager.notificationsEnabled = notificationsEnabled
            self?.settingsManager.announcements = announcementsEnabled
            group.leave()
        }

        if topicService == nil {
            topicService = alertServiceFactory.createTopicService()
        }

        topicService?.save(settings: topics) {
            group.leave()
        }

        group.notify(queue: .main) {
            self.presenter?.didReceiveSaveCompletion()
        }
    }

    func remakeSubscription() {
        subscribeToSettings()
        subscribeToTopicsSettings()
    }
}

extension NotificationsManagementInteractor: SettingsSubscriber, SettingsSubscriptionHandler {
    func handlePushNotificationsSettings(result: Result<[DataProviderChange<LocalPushSettings>], Error>) {
        DispatchQueue.main.async {
            switch result {
            case let .success(changes):
                if let settings = changes.reduceToLastChange() {
                    self.presenter?.didReceive(settings: settings)
                }
            case let .failure(error):
                self.presenter?.didReceive(error: .settingsSubscription(error))
            }
        }
    }

    func handleTopicsSettings(result: Result<[DataProviderChange<LocalNotificationTopicSettings>], Error>) {
        DispatchQueue.main.async {
            switch result {
            case let .success(changes):
                if let settings = changes.reduceToLastChange() {
                    self.presenter?.didReceive(topicsSettings: settings)
                }
            case let .failure(error):
                self.presenter?.didReceive(error: .settingsSubscription(error))
            }
        }
    }
}
