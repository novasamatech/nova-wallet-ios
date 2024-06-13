import Foundation
import Operation_iOS

protocol SettingsSubscriptionHandler: AnyObject {
    func handlePushNotificationsSettings(
        result: Result<[DataProviderChange<Web3Alert.LocalSettings>], Error>
    )
    func handleTopicsSettings(
        result: Result<[DataProviderChange<PushNotification.TopicSettings>], Error>
    )
}

extension SettingsSubscriptionHandler {
    func handlePushNotificationsSettings(
        result _: Result<[DataProviderChange<Web3Alert.LocalSettings>], Error>
    ) {}
    func handleTopicsSettings(
        result _: Result<[DataProviderChange<PushNotification.TopicSettings>], Error>
    ) {}
}
