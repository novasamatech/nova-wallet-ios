import UIKit
import RobinHood
import SoraKeystore

final class NotificationsManagementInteractor: AnyProviderAutoCleaning {
    weak var presenter: NotificationsManagementInteractorOutputProtocol?
    let settingsLocalSubscriptionFactory: SettingsLocalSubscriptionFactoryProtocol
    let settingsManager: SettingsManagerProtocol
    let alertServiceFactory: Web3AlertsServicesFactoryProtocol

    private var settingsProvider: StreamableProvider<Web3Alert.LocalSettings>?
    private var topicsSettingsProvider: StreamableProvider<PushNotification.TopicSettings>?
    private var syncService: Web3AlertsSyncServiceProtocol?
    private var pushService: PushNotificationsServiceProtocol?
    private var topicService: TopicServiceProtocol?
    private let workingQueue: OperationQueue
    private let callbackQueue: DispatchQueue

    init(
        settingsLocalSubscriptionFactory: SettingsLocalSubscriptionFactoryProtocol,
        settingsManager: SettingsManagerProtocol,
        alertServiceFactory: Web3AlertsServicesFactoryProtocol,
        workingQueue: OperationQueue = OperationManagerFacade.sharedDefaultQueue,
        callbackQueue: DispatchQueue = .global()
    ) {
        self.workingQueue = workingQueue
        self.callbackQueue = callbackQueue
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

    func checkNotificationsAvailability() {
        if pushService?.statusObservable.state == .denied {
            DispatchQueue.main.async {
                self.presenter?.didReceive(error: .notificationsDisabledInSettings)
            }
        }
    }

    func save(
        settings: Web3Alert.LocalSettings,
        topics: PushNotification.TopicSettings,
        notificationsEnabled: Bool,
        announcementsEnabled: Bool
    ) {
        if syncService == nil {
            syncService = alertServiceFactory.createSyncService()
        }

        let group = DispatchGroup()
        group.enter()

        syncService?.save(settings: settings, runningInQueue: callbackQueue) { [weak self] error in
            defer {
                group.leave()
            }
            if let error = error {
                self?.presenter?.didReceive(error: .save(error))
                return
            }
            self?.settingsManager.notificationsEnabled = notificationsEnabled
        }

        if topicService == nil {
            group.enter()
            topicService = alertServiceFactory.createTopicService()
        }

        topicService?.save(
            settings: topics,
            workingQueue: workingQueue,
            callbackQueue: callbackQueue
        ) { [weak self] in
            self?.settingsManager.announcements = announcementsEnabled
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
