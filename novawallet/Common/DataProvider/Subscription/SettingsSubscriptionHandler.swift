import Foundation
import RobinHood

protocol SettingsSubscriptionHandler: AnyObject {
    func handlePushNotificationsSettings(
        result: Result<[DataProviderChange<LocalPushSettings>], Error>
    )
    func handleTopicsSettings(
        result: Result<[DataProviderChange<LocalNotificationTopicSettings>], Error>
    )
}

extension SettingsSubscriptionHandler {
    func handlePushNotificationsSettings(
        result _: Result<[DataProviderChange<LocalPushSettings>], Error>
    ) {}
    func handleTopicsSettings(
        result _: Result<[DataProviderChange<LocalNotificationTopicSettings>], Error>
    ) {}
}
