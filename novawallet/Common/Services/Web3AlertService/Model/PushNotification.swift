import Foundation

extension PushNotification {
    struct AllSettings {
        let notificationsEnabled: Bool
        let accountBased: Web3Alert.LocalSettings
        let topics: TopicSettings
    }
}
