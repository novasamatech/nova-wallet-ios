import UIKit
import RobinHood
import SoraKeystore

final class NotificationsManagementInteractor: AnyProviderAutoCleaning {
    weak var presenter: NotificationsManagementInteractorOutputProtocol?
    let settingsLocalSubscriptionFactory: SettingsLocalSubscriptionFactoryProtocol
    let settingsManager: SettingsManagerProtocol
    let alertServiceFactory: Web3AlertsServicesFactoryProtocol

    private var settingsProvider: StreamableProvider<LocalPushSettings>?
    private var syncService: Web3AlertsSyncServiceProtocol?
    private var pushService: PushNotificationsServiceProtocol?

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

        pushService?.status { [weak self] status in
            DispatchQueue.main.async {
                self?.presenter?.didReceive(notificationsEnabled: status == .on)
            }
        }
    }
}

extension NotificationsManagementInteractor: NotificationsManagementInteractorInputProtocol {
    func setup() {
        subscribeToSettings()
        provideAnnouncementsFlag()
        provideNotificationsStatus()
    }

    func enableNotifications() {
        pushService?.status { [weak self] status in
            if status == .denied {
                DispatchQueue.main.async {
                    self?.presenter?.didReceive(error: .notificationsDisabledInSettings)
                    self?.presenter?.didReceive(notificationsEnabled: false)
                }
            }
        }
    }

    func save(
        settings: LocalPushSettings,
        notificationsEnabled: Bool,
        announcementsEnabled: Bool
    ) {
        if syncService == nil {
            syncService = alertServiceFactory.createSyncService()
        }

        syncService?.save(settings: settings) { [weak self] in
            self?.settingsManager.notificationsEnabled = notificationsEnabled
            self?.settingsManager.announcements = announcementsEnabled
            DispatchQueue.main.async {
                self?.presenter?.didReceiveSaveCompletion()
            }
        }
    }

    func remakeSubscription() {
        subscribeToSettings()
    }

    func checkNotificationsStatus() {
        modifiedNotificationsEnabled = nil
        provideNotificationsStatus()
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
}
