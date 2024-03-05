import RobinHood

extension PushNotification {
    struct TopicSettings: Codable, Equatable, Identifiable {
        var identifier: String { Self.getIdentifier() }
        let topics: [PushNotification.Topic]

        init(
            topics: [PushNotification.Topic]
        ) {
            self.topics = topics
        }

        static func getIdentifier() -> String {
            "LocalNotificationTopicSettingsIdentifier"
        }
    }
}
