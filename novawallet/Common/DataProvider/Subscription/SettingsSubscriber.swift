import Foundation
import RobinHood

protocol SettingsSubscriber: AnyObject {
    var settingsLocalSubscriptionFactory: SettingsLocalSubscriptionFactoryProtocol { get }
    var settingsSubscriptionHandler: SettingsSubscriptionHandler { get }

    func subscribeToPushSettings() -> StreamableProvider<LocalPushSettings>?
}

extension SettingsSubscriber {
    func subscribeToPushSettings() -> StreamableProvider<LocalPushSettings>? {
        guard let provider = settingsLocalSubscriptionFactory.getPushSettingsProvider() else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<LocalPushSettings>]) in
            self?.settingsSubscriptionHandler.handlePushNotificationsSettings(result: .success(changes))
            return
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.settingsSubscriptionHandler.handlePushNotificationsSettings(result: .failure(error))
            return
        }

        let options = StreamableProviderObserverOptions(
            alwaysNotifyOnRefresh: true,
            waitsInProgressSyncOnAdd: false,
            initialSize: 0,
            refreshWhenEmpty: false
        )

        provider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        return provider
    }
}

extension SettingsSubscriber where Self: SettingsSubscriptionHandler {
    var settingsSubscriptionHandler: SettingsSubscriptionHandler { self }
}
