import Foundation
import Operation_iOS

protocol SettingsSubscriber: AnyObject {
    var settingsLocalSubscriptionFactory: SettingsLocalSubscriptionFactoryProtocol { get }
    var settingsSubscriptionHandler: SettingsSubscriptionHandler { get }

    func subscribeToPushSettings() -> StreamableProvider<Web3Alert.LocalSettings>?
    func subscribeToTopicsSettings() -> StreamableProvider<PushNotification.TopicSettings>?
}

extension SettingsSubscriber {
    func subscribeToPushSettings() -> StreamableProvider<Web3Alert.LocalSettings>? {
        guard let provider = settingsLocalSubscriptionFactory.getPushSettingsProvider() else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<Web3Alert.LocalSettings>]) in
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

    func subscribeToTopicsSettings() -> StreamableProvider<PushNotification.TopicSettings>? {
        guard let provider = settingsLocalSubscriptionFactory.getTopicsProvider() else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<PushNotification.TopicSettings>]) in
            self?.settingsSubscriptionHandler.handleTopicsSettings(result: .success(changes))
            return
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.settingsSubscriptionHandler.handleTopicsSettings(result: .failure(error))
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
