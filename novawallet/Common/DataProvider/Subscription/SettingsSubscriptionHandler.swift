import Foundation
import RobinHood

protocol SettingsSubscriptionHandler: AnyObject {
    func handlePushNotificationsSettings(
        result: Result<[DataProviderChange<LocalPushSettings>], Error>
    )
}

extension SettingsSubscriptionHandler {
    func handlePushNotificationsSettings(
        result _: Result<[DataProviderChange<LocalPushSettings>], Error>
    ) {}
}
