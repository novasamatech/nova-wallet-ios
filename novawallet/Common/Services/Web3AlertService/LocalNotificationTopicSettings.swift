import RobinHood

struct LocalNotificationTopicSettings: Codable, Equatable, Identifiable {
    var identifier: String { Self.getIdentifier() }
    let topics: [NotificationTopic]

    init(
        topics: [NotificationTopic]
    ) {
        self.topics = topics
    }

    static func getIdentifier() -> String {
        "LocalNotificationTopicSettingsIdentifier"
    }
}
